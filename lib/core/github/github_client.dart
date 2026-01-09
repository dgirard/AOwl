import 'package:dio/dio.dart';

import 'github_auth.dart';
import 'github_errors.dart';
import 'rate_limit_tracker.dart';

/// Dio-based HTTP client for GitHub API.
///
/// Includes:
/// - Authentication header injection
/// - Rate limit tracking
/// - Error mapping to typed errors
/// - Retry logic for transient failures
class GitHubClient {
  final Dio _dio;
  final GitHubAuth auth;
  final RateLimitTracker rateLimits = RateLimitTracker();

  /// Maximum retry attempts for transient errors.
  final int maxRetries;

  /// Base delay between retries (exponential backoff).
  final Duration retryDelay;

  GitHubClient({
    required this.auth,
    Dio? dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  }) : _dio = dio ?? Dio() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.options.baseUrl = auth.baseUrl;
    _dio.options.headers = auth.headers;
    _dio.options.validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // Track rate limits from every response
        rateLimits.updateFromHeaders(response.headers.map);
        handler.next(response);
      },
      onError: (error, handler) {
        // Map Dio errors to our error types
        handler.next(error);
      },
    ));
  }

  /// Performs a GET request with retry logic.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _withRetry(() => _dio.get<T>(
          path,
          queryParameters: queryParameters,
        ));
  }

  /// Performs a PUT request with retry logic.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    return _withRetry(() => _dio.put<T>(path, data: data));
  }

  /// Performs a DELETE request with retry logic.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
  }) async {
    return _withRetry(() => _dio.delete<T>(path, data: data));
  }

  /// Executes request with exponential backoff retry.
  Future<Response<T>> _withRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    var attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await request();

        // Check for rate limit errors
        if (response.statusCode == 403 || response.statusCode == 429) {
          final data = response.data;
          final message = (data is Map)
              ? data['message']?.toString() ?? ''
              : '';
          if (message.contains('rate limit') ||
              response.statusCode == 429) {
            throw _mapError(response);
          }
        }

        // Check for server errors that might be retryable
        if (response.statusCode != null && response.statusCode! >= 500) {
          if (attempts < maxRetries) {
            await Future.delayed(retryDelay * attempts);
            continue;
          }
          throw _mapError(response);
        }

        return response;
      } on DioException catch (e) {
        if (attempts < maxRetries && _isRetryable(e)) {
          await Future.delayed(retryDelay * attempts);
          continue;
        }
        throw _mapDioError(e);
      }
    }
  }

  bool _isRetryable(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  GitHubError _mapError(Response response) {
    final status = response.statusCode;
    final data = response.data;
    final message = (data is Map) ? data['message']?.toString() : null;

    if (status == null) {
      return UnknownGitHubError(message ?? 'Unknown error', null);
    }

    return switch (status) {
      401 => const AuthenticationFailed(),
      403 => _checkRateLimit(response) ?? const AccessForbidden(),
      404 => NotFound(response.requestOptions.path),
      409 => ConflictError(response.requestOptions.path),
      429 => RateLimitExceeded(
          resetAt: rateLimits.resetAt,
          remaining: rateLimits.remaining,
        ),
      >= 500 && < 600 => ServerError(status, message),
      _ => UnknownGitHubError(message ?? 'Unknown error', status),
    };
  }

  GitHubError? _checkRateLimit(Response response) {
    final message = (response.data is Map)
        ? response.data['message']?.toString() ?? ''
        : '';
    if (message.contains('rate limit')) {
      return RateLimitExceeded(
        resetAt: rateLimits.resetAt,
        remaining: rateLimits.remaining,
      );
    }
    return null;
  }

  GitHubError _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NetworkError('Connection timeout: ${e.message}'),
      DioExceptionType.connectionError =>
        NetworkError('Connection failed: ${e.message}'),
      DioExceptionType.badResponse when e.response != null =>
        _mapError(e.response!),
      _ => NetworkError(e.message ?? 'Unknown network error'),
    };
  }

  /// Closes the client and releases resources.
  void close() {
    _dio.close();
  }
}
