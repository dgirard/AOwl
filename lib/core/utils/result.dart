/// A type-safe result that is either a success with value [T]
/// or a failure with error [E].
///
/// Usage:
/// ```dart
/// Result<String, CryptoError> result = decrypt(data);
/// switch (result) {
///   case Success(:final value):
///     print('Decrypted: $value');
///   case Failure(:final error):
///     print('Error: $error');
/// }
/// ```
sealed class Result<T, E> {
  const Result();

  /// Returns `true` if this is a [Success].
  bool get isSuccess => this is Success<T, E>;

  /// Returns `true` if this is a [Failure].
  bool get isFailure => this is Failure<T, E>;

  /// Returns the success value or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  /// Returns the error or `null` if this is a success.
  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final error) => error,
      };

  /// Returns the success value or throws the error.
  T get valueOrThrow => switch (this) {
        Success(:final value) => value,
        Failure(:final error) => throw error as Object,
      };

  /// Transforms the success value using [transform].
  Result<U, E> map<U>(U Function(T value) transform) => switch (this) {
        Success(:final value) => Success(transform(value)),
        Failure(:final error) => Failure(error),
      };

  /// Transforms the error using [transform].
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
        Success(:final value) => Success(value),
        Failure(:final error) => Failure(transform(error)),
      };

  /// Chains another result-producing operation.
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) =>
      switch (this) {
        Success(:final value) => transform(value),
        Failure(:final error) => Failure(error),
      };
}

/// A successful result containing [value].
final class Success<T, E> extends Result<T, E> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// A failed result containing [error].
final class Failure<T, E> extends Result<T, E> {
  final E error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}
