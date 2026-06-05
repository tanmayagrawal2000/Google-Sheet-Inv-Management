import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../shared/models/user_session.dart';
import '../data/user_repository.dart';

enum UserSessionStatus { initial, loading, authenticated, error }

class UserSessionState extends Equatable {
  const UserSessionState({
    this.status = UserSessionStatus.initial,
    this.session,
    this.error,
  });

  final UserSessionStatus status;
  final UserSession? session;
  final String? error;

  bool get isAuthenticated => status == UserSessionStatus.authenticated;
  bool get isLoading => status == UserSessionStatus.loading;

  UserSessionState copyWith({
    UserSessionStatus? status,
    UserSession? session,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) =>
      UserSessionState(
        status: status ?? this.status,
        session: clearSession ? null : (session ?? this.session),
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, session, error];
}

class UserSessionCubit extends Cubit<UserSessionState> {
  UserSessionCubit(this._userRepo) : super(const UserSessionState());

  final UserRepository _userRepo;

  /// Authenticates with [username]/[password].
  /// On success emits authenticated state; on failure emits error.
  Future<void> login(String username, String password) async {
    emit(state.copyWith(
        status: UserSessionStatus.loading, clearError: true));
    try {
      final session =
          await _userRepo.authenticate(username.trim(), password);
      if (session == null) {
        emit(state.copyWith(
          status: UserSessionStatus.error,
          error: 'Invalid username or password.',
        ));
      } else {
        emit(state.copyWith(
            status: UserSessionStatus.authenticated, session: session));
      }
    } catch (e) {
      emit(state.copyWith(
        status: UserSessionStatus.error,
        error: 'Login failed: $e',
      ));
    }
  }

  /// Clears the current session. Does NOT affect the Google OAuth token.
  void logout() {
    emit(const UserSessionState());
  }
}
