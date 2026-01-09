/// Tracks GitHub API rate limit status.
///
/// GitHub provides 5000 requests per hour for authenticated users.
/// This tracker parses rate limit headers and warns when approaching limits.
class RateLimitTracker {
  /// Maximum requests per hour.
  int? limit;

  /// Remaining requests in current window.
  int? remaining;

  /// Time when the rate limit resets.
  DateTime? resetAt;

  /// Threshold for warning (default: 100 requests remaining).
  final int warningThreshold;

  RateLimitTracker({this.warningThreshold = 100});

  /// Updates rate limit info from response headers.
  void updateFromHeaders(Map<String, dynamic> headers) {
    final limitHeader = headers['x-ratelimit-limit'];
    final remainingHeader = headers['x-ratelimit-remaining'];
    final resetHeader = headers['x-ratelimit-reset'];

    if (limitHeader != null) {
      limit = int.tryParse(limitHeader.toString());
    }

    if (remainingHeader != null) {
      remaining = int.tryParse(remainingHeader.toString());
    }

    if (resetHeader != null) {
      final timestamp = int.tryParse(resetHeader.toString());
      if (timestamp != null) {
        resetAt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
  }

  /// Returns true if rate limit is near exhaustion.
  bool get isNearLimit => remaining != null && remaining! < warningThreshold;

  /// Returns true if rate limit is exhausted.
  bool get isExhausted => remaining != null && remaining! <= 0;

  /// Returns time until rate limit resets, or null if unknown.
  Duration? get timeUntilReset {
    if (resetAt == null) return null;
    final now = DateTime.now();
    if (resetAt!.isBefore(now)) return Duration.zero;
    return resetAt!.difference(now);
  }

  /// Returns a human-readable status string.
  String get status {
    if (remaining == null || limit == null) {
      return 'Rate limit: unknown';
    }
    final resetStr = resetAt != null
        ? ' (resets at ${resetAt!.toLocal().toString().substring(11, 19)})'
        : '';
    return 'Rate limit: $remaining/$limit remaining$resetStr';
  }

  @override
  String toString() => status;
}
