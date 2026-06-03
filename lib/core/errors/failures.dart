/// Typed errors surfaced to cubits/UI so they can show meaningful messages.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// User is not signed in / token could not be obtained.
class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// Network or Google API error (after retries).
class ApiFailure extends AppFailure {
  const ApiFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// No internet connection.
class OfflineFailure extends AppFailure {
  const OfflineFailure([super.message = 'No internet connection.']);
}

/// Local configuration problem (e.g. missing OAuth client id).
class ConfigFailure extends AppFailure {
  const ConfigFailure(super.message);
}
