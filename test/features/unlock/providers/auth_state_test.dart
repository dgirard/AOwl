import 'dart:typed_data';

import 'package:ashare/features/unlock/providers/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState sealed classes', () {
    test('AuthStateInitializing', () {
      const state = AuthStateInitializing();
      expect(state.toString(), contains('Initializing'));
    });

    test('AuthStateNotConfigured', () {
      const state = AuthStateNotConfigured();
      expect(state.toString(), contains('NotConfigured'));
    });

    group('AuthStateLocked', () {
      test('creates with default values', () {
        const state = AuthStateLocked();
        expect(state.failedAttempts, equals(0));
        expect(state.lockoutUntil, isNull);
        expect(state.isLockedOut, isFalse);
      });

      test('tracks failed attempts', () {
        const state = AuthStateLocked(failedAttempts: 3);
        expect(state.failedAttempts, equals(3));
      });

      test('detects lockout', () {
        final futureTime = DateTime.now().add(const Duration(minutes: 5));
        final state = AuthStateLocked(lockoutUntil: futureTime);

        expect(state.isLockedOut, isTrue);
        expect(state.remainingLockout, isNotNull);
        expect(state.remainingLockout!.inMinutes, greaterThan(0));
      });

      test('expired lockout returns false', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
        final state = AuthStateLocked(lockoutUntil: pastTime);

        expect(state.isLockedOut, isFalse);
        expect(state.remainingLockout, isNull);
      });
    });

    test('AuthStateUnlocked holds master key', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final state = AuthStateUnlocked(masterKey: key);

      expect(state.masterKey, equals(key));
      expect(state.toString(), contains('32 bytes'));
    });

    test('AuthStateError holds error', () {
      const error = WrongPinError(3);
      const state = AuthStateError(error);

      expect(state.error, equals(error));
    });

    group('pattern matching', () {
      test('works with switch statement', () {
        AuthState state = const AuthStateInitializing();

        String result = switch (state) {
          AuthStateInitializing() => 'initializing',
          AuthStateNotConfigured() => 'not configured',
          AuthStateLocked() => 'locked',
          AuthStateUnlocked() => 'unlocked',
          AuthStateError() => 'error',
        };

        expect(result, equals('initializing'));
      });

      test('exhaustive switch for all states', () {
        final states = <AuthState>[
          const AuthStateInitializing(),
          const AuthStateNotConfigured(),
          const AuthStateLocked(),
          AuthStateUnlocked(masterKey: Uint8List(32)),
          const AuthStateError(WrongPinError(1)),
        ];

        for (final state in states) {
          // This will fail to compile if not exhaustive
          final _ = switch (state) {
            AuthStateInitializing() => 1,
            AuthStateNotConfigured() => 2,
            AuthStateLocked() => 3,
            AuthStateUnlocked() => 4,
            AuthStateError() => 5,
          };
        }
      });
    });
  });

  group('AuthError sealed classes', () {
    test('WrongPinError', () {
      const error = WrongPinError(2);

      expect(error.attemptsRemaining, equals(2));
      expect(error.message, contains('2 attempts'));
    });

    test('LockedOutError', () {
      const error = LockedOutError(Duration(minutes: 15));

      expect(error.duration, equals(const Duration(minutes: 15)));
      expect(error.message, contains('15 minutes'));
    });

    test('LockedOutError with seconds', () {
      const error = LockedOutError(Duration(seconds: 30));

      expect(error.message, contains('30 seconds'));
    });

    test('StorageError', () {
      const error = StorageError('Keychain access denied');

      expect(error.details, equals('Keychain access denied'));
      expect(error.message, contains('Storage error'));
    });

    test('KeyDerivationError', () {
      const error = KeyDerivationError('Memory allocation failed');

      expect(error.details, equals('Memory allocation failed'));
      expect(error.message, contains('derive key'));
    });

    test('SetupValidationError', () {
      const error = SetupValidationError('Invalid PIN format');

      expect(error.details, equals('Invalid PIN format'));
      expect(error.message, equals('Invalid PIN format'));
    });

    group('pattern matching', () {
      test('exhaustive switch for all errors', () {
        final errors = <AuthError>[
          const WrongPinError(1),
          const LockedOutError(Duration(minutes: 1)),
          const StorageError('test'),
          const KeyDerivationError('test'),
          const SetupValidationError('test'),
        ];

        for (final error in errors) {
          // This will fail to compile if not exhaustive
          final _ = switch (error) {
            WrongPinError() => 1,
            LockedOutError() => 2,
            StorageError() => 3,
            KeyDerivationError() => 4,
            SetupValidationError() => 5,
          };
        }
      });
    });
  });
}
