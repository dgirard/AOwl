/// Sealed hierarchy of GitHub API errors.
sealed class GitHubError {
  const GitHubError();

  /// Human-readable error message.
  String get message;
}

/// Authentication failed (401).
final class AuthenticationFailed extends GitHubError {
  const AuthenticationFailed();

  @override
  String get message => 'Authentication failed - check your token';
}

/// Resource not found (404).
final class NotFound extends GitHubError {
  final String path;

  const NotFound(this.path);

  @override
  String get message => 'Resource not found: $path';
}

/// Conflict during update (409) - file was modified.
final class ConflictError extends GitHubError {
  final String path;
  final String? expectedSha;

  const ConflictError(this.path, [this.expectedSha]);

  @override
  String get message => 'Conflict: $path was modified (expected SHA: $expectedSha)';
}

/// Rate limit exceeded (403 or 429).
final class RateLimitExceeded extends GitHubError {
  final DateTime? resetAt;
  final int? remaining;

  const RateLimitExceeded({this.resetAt, this.remaining});

  @override
  String get message {
    if (resetAt != null) {
      return 'Rate limit exceeded - resets at $resetAt';
    }
    return 'Rate limit exceeded';
  }
}

/// Repository access forbidden (403).
final class AccessForbidden extends GitHubError {
  const AccessForbidden();

  @override
  String get message => 'Access forbidden - check repository permissions';
}

/// Network error (connection failed, timeout).
final class NetworkError extends GitHubError {
  final String details;

  const NetworkError(this.details);

  @override
  String get message => 'Network error: $details';
}

/// Server error (5xx).
final class ServerError extends GitHubError {
  final int statusCode;
  final String? details;

  const ServerError(this.statusCode, [this.details]);

  @override
  String get message => 'GitHub server error ($statusCode): ${details ?? 'Unknown error'}';
}

/// Unknown or unhandled error.
final class UnknownGitHubError extends GitHubError {
  final int? statusCode;
  final String details;

  const UnknownGitHubError(this.details, [this.statusCode]);

  @override
  String get message => 'GitHub error: $details';
}
