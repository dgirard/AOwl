import 'package:ashare/core/github/rate_limit_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateLimitTracker', () {
    late RateLimitTracker tracker;

    setUp(() {
      tracker = RateLimitTracker();
    });

    test('starts with null values', () {
      expect(tracker.limit, isNull);
      expect(tracker.remaining, isNull);
      expect(tracker.resetAt, isNull);
    });

    test('parses headers correctly', () {
      final now = DateTime.now();
      final resetTimestamp = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

      tracker.updateFromHeaders({
        'x-ratelimit-limit': '5000',
        'x-ratelimit-remaining': '4999',
        'x-ratelimit-reset': '$resetTimestamp',
      });

      expect(tracker.limit, equals(5000));
      expect(tracker.remaining, equals(4999));
      expect(tracker.resetAt, isNotNull);
    });

    test('handles string header values', () {
      tracker.updateFromHeaders({
        'x-ratelimit-limit': 5000,
        'x-ratelimit-remaining': 100,
      });

      expect(tracker.limit, equals(5000));
      expect(tracker.remaining, equals(100));
    });

    group('isNearLimit', () {
      test('returns false when remaining is null', () {
        expect(tracker.isNearLimit, isFalse);
      });

      test('returns false when remaining is above threshold', () {
        tracker.updateFromHeaders({
          'x-ratelimit-remaining': '500',
        });
        expect(tracker.isNearLimit, isFalse);
      });

      test('returns true when remaining is below threshold', () {
        tracker.updateFromHeaders({
          'x-ratelimit-remaining': '50',
        });
        expect(tracker.isNearLimit, isTrue);
      });

      test('respects custom threshold', () {
        final customTracker = RateLimitTracker(warningThreshold: 500);
        customTracker.updateFromHeaders({
          'x-ratelimit-remaining': '300',
        });
        expect(customTracker.isNearLimit, isTrue);
      });
    });

    group('isExhausted', () {
      test('returns false when remaining is null', () {
        expect(tracker.isExhausted, isFalse);
      });

      test('returns false when remaining is above zero', () {
        tracker.updateFromHeaders({
          'x-ratelimit-remaining': '1',
        });
        expect(tracker.isExhausted, isFalse);
      });

      test('returns true when remaining is zero', () {
        tracker.updateFromHeaders({
          'x-ratelimit-remaining': '0',
        });
        expect(tracker.isExhausted, isTrue);
      });
    });

    group('timeUntilReset', () {
      test('returns null when resetAt is null', () {
        expect(tracker.timeUntilReset, isNull);
      });

      test('returns Duration.zero when reset time has passed', () {
        final pastTime = DateTime.now().subtract(const Duration(hours: 1));
        tracker.updateFromHeaders({
          'x-ratelimit-reset': '${pastTime.millisecondsSinceEpoch ~/ 1000}',
        });
        expect(tracker.timeUntilReset, equals(Duration.zero));
      });

      test('returns positive duration when reset is in future', () {
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        tracker.updateFromHeaders({
          'x-ratelimit-reset': '${futureTime.millisecondsSinceEpoch ~/ 1000}',
        });
        expect(tracker.timeUntilReset!.inMinutes, greaterThan(50));
      });
    });

    group('status', () {
      test('shows unknown when values are null', () {
        expect(tracker.status, contains('unknown'));
      });

      test('shows remaining/limit when set', () {
        tracker.updateFromHeaders({
          'x-ratelimit-limit': '5000',
          'x-ratelimit-remaining': '4500',
        });
        expect(tracker.status, contains('4500/5000'));
      });
    });
  });
}
