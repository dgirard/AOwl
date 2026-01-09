import 'dart:typed_data';

/// Sealed hierarchy of authentication states.
///
/// Using sealed classes ensures exhaustive switch handling.
sealed class AuthState {
  const AuthState();
}

/// Initial state - checking if vault is configured.
final class AuthStateInitializing extends AuthState {
  const AuthStateInitializing();

  @override
  String toString() => 'AuthStateInitializing';
}

/// No vault configured - needs setup.
final class AuthStateNotConfigured extends AuthState {
  const AuthStateNotConfigured();

  @override
  String toString() => 'AuthStateNotConfigured';
}

/// Vault is locked - waiting for PIN unlock.
final class AuthStateLocked extends AuthState {
  /// Number of failed PIN attempts.
  final int failedAttempts;

  /// If locked out, when the lockout expires.
  final DateTime? lockoutUntil;

  const AuthStateLocked({
    this.failedAttempts = 0,
    this.lockoutUntil,
  });

  /// Returns true if currently in lockout period.
  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  /// Returns remaining lockout duration.
  Duration? get remainingLockout {
    if (lockoutUntil == null) return null;
    final remaining = lockoutUntil!.difference(DateTime.now());
    if (remaining.isNegative) return null;
    return remaining;
  }

  @override
  String toString() => 'AuthStateLocked(failed: $failedAttempts, lockout: $lockoutUntil)';
}

/// Vault is unlocked - master key available.
final class AuthStateUnlocked extends AuthState {
  /// The derived master encryption key.
  final Uint8List masterKey;

  const AuthStateUnlocked({required this.masterKey});

  @override
  String toString() => 'AuthStateUnlocked(key: ${masterKey.length} bytes)';
}

/// Authentication error occurred.
final class AuthStateError extends AuthState {
  final AuthError error;

  const AuthStateError(this.error);

  @override
  String toString() => 'AuthStateError($error)';
}

/// Sealed hierarchy of authentication errors.
sealed class AuthError {
  const AuthError();

  String get message;
}

/// Wrong PIN entered.
final class WrongPinError extends AuthError {
  final int attemptsRemaining;

  const WrongPinError(this.attemptsRemaining);

  @override
  String get message => 'Wrong PIN. $attemptsRemaining attempts remaining.';

  @override
  String toString() => 'WrongPinError($attemptsRemaining remaining)';
}

/// Too many failed attempts - locked out.
final class LockedOutError extends AuthError {
  final Duration duration;

  const LockedOutError(this.duration);

  @override
  String get message {
    final minutes = duration.inMinutes;
    if (minutes > 0) {
      return 'Too many failed attempts. Try again in $minutes minutes.';
    }
    final seconds = duration.inSeconds;
    return 'Too many failed attempts. Try again in $seconds seconds.';
  }

  @override
  String toString() => 'LockedOutError(${duration.inMinutes}m)';
}

/// Storage error (Keychain/Keystore).
final class StorageError extends AuthError {
  final String details;

  const StorageError(this.details);

  @override
  String get message => 'Storage error: $details';

  @override
  String toString() => 'StorageError($details)';
}

/// Key derivation failed.
final class KeyDerivationError extends AuthError {
  final String details;

  const KeyDerivationError(this.details);

  @override
  String get message => 'Failed to derive key: $details';

  @override
  String toString() => 'KeyDerivationError($details)';
}

/// Setup validation error.
final class SetupValidationError extends AuthError {
  final String details;

  const SetupValidationError(this.details);

  @override
  String get message => details;

  @override
  String toString() => 'SetupValidationError($details)';
}
