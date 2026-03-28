import 'package:fpdart/fpdart.dart';

sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error occurred']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication error occurred']);
}

class UnsupportedFeatureFailure extends Failure {
  const UnsupportedFeatureFailure([
    super.message = 'This feature is not supported on this device',
  ]);
}

/// Convenience typedef for `Either<Failure, T>`
typedef AppResult<T> = Either<Failure, T>;
