import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/backoff_client.dart';
import 'secure_token_store.dart';

/// User-facing auth state.
enum AuthStatus { unknown, signedOut, signedIn }

/// Abstraction over Google OAuth so the rest of the app never depends directly
/// on a specific sign-in package. Backed by [GsiAuthService] today; can be
/// swapped (e.g. native google_sign_in on mobile + oauth2 loopback on desktop)
/// without touching feature code.
abstract class AuthService {
  /// Emits whenever the signed-in state changes.
  Stream<AuthStatus> get statusChanges;

  /// Attempts a non-interactive sign-in from stored credentials. Returns true
  /// if a session was restored.
  Future<bool> trySilentSignIn();

  /// Interactive sign-in (opens browser/native flow). Throws [AppFailure].
  Future<void> signIn();

  Future<void> signOut();

  /// A googleapis-ready, auto-refreshing, backoff-wrapped HTTP client. Throws
  /// [AuthFailure] if the user is not authenticated.
  Future<http.Client> authenticatedClient();
}

class GsiAuthService implements AuthService {
  GsiAuthService(this._tokenStore) {
    _gsi = GoogleSignIn(
      params: GoogleSignInParams(
        scopes: AppConfig.scopes,
        clientId: _needsExplicitClientId ? _requireClientId() : AppConfig.mobileClientIdOrNull,
        clientSecret: _isDesktop ? AppConfig.desktopClientSecret : null,
        saveAccessToken: _tokenStore.save,
        retrieveAccessToken: _tokenStore.retrieve,
        deleteAccessToken: _tokenStore.delete,
      ),
    );
    _sub = _gsi.authenticationState.listen((creds) {
      _controller.add(creds != null ? AuthStatus.signedIn : AuthStatus.signedOut);
    });
  }

  final SecureTokenStore _tokenStore;
  late final GoogleSignIn _gsi;
  late final StreamSubscription<GoogleSignInCredentials?> _sub;
  final _controller = StreamController<AuthStatus>.broadcast();

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get _needsExplicitClientId => _isDesktop || kIsWeb;

  static String _requireClientId() {
    if (!AppConfig.hasDesktopCredentials) {
      throw const ConfigFailure(
        'Missing Google OAuth client ID. Pass it via '
        '--dart-define=GOOGLE_DESKTOP_CLIENT_ID=... '
        '(see docs/google_cloud_setup.md).',
      );
    }
    return AppConfig.desktopClientId;
  }

  @override
  Stream<AuthStatus> get statusChanges => _controller.stream;

  @override
  Future<bool> trySilentSignIn() async {
    try {
      // On desktop, silentSignIn restores from stored creds; on mobile the
      // lightweight path is preferred. signIn() tries lightweight first.
      final creds = _isDesktop ? await _gsi.silentSignIn() : await _gsi.lightweightSignIn();
      return creds != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signIn() async {
    try {
      final creds = await _gsi.signInOnline();
      if (creds == null) {
        throw const AuthFailure('Sign-in was cancelled or failed.');
      }
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure('Sign-in failed: $e');
    }
  }

  @override
  Future<void> signOut() => _gsi.signOut();

  @override
  Future<http.Client> authenticatedClient() async {
    final client = await _gsi.authenticatedClient;
    if (client == null) {
      throw const AuthFailure('Not signed in.');
    }
    return BackoffClient(client);
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
