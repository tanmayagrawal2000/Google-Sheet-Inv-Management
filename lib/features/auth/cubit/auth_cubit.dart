import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/failures.dart';
import '../data/auth_service.dart';

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final bool busy;
  final String? error;

  AuthState copyWith({AuthStatus? status, bool? busy, String? error, bool clearError = false}) =>
      AuthState(
        status: status ?? this.status,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, busy, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._auth) : super(const AuthState()) {
    _sub = _auth.statusChanges.listen((status) {
      emit(state.copyWith(status: status, busy: false));
    });
  }

  final AuthService _auth;
  late final StreamSubscription<AuthStatus> _sub;

  /// Called on app start to restore an existing session.
  Future<void> bootstrap() async {
    final restored = await _auth.trySilentSignIn();
    if (!restored) {
      emit(state.copyWith(status: AuthStatus.signedOut));
    }
  }

  Future<void> signIn() async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _auth.signIn();
      // statusChanges stream will flip status to signedIn.
    } on AppFailure catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(busy: false, error: 'Unexpected error: $e'));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
