import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../shared/models/managed_user.dart';
import '../../../shared/models/user_session.dart';
import '../data/user_repository.dart';

class UserManagementState extends Equatable {
  const UserManagementState({
    this.users = const [],
    this.categoryNames = const [],
    this.loading = false,
    this.error,
  });

  final List<ManagedUser> users;
  final List<String> categoryNames;
  final bool loading;
  final String? error;

  UserManagementState copyWith({
    List<ManagedUser>? users,
    List<String>? categoryNames,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      UserManagementState(
        users: users ?? this.users,
        categoryNames: categoryNames ?? this.categoryNames,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [users, categoryNames, loading, error];
}

class UserManagementCubit extends Cubit<UserManagementState> {
  UserManagementCubit(this._repo) : super(const UserManagementState());

  final UserRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _repo.loadAllUsers();
      emit(state.copyWith(
        loading: false,
        users: result.users,
        categoryNames: result.categoryNames,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<bool> addUser(String username, String password,
      {bool isAdmin = false}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repo.addUser(username, password, isAdmin: isAdmin);
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
      return false;
    }
  }

  Future<bool> deleteUser(ManagedUser user) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repo.deleteUser(user);
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
      return false;
    }
  }

  Future<bool> updatePermission(
      ManagedUser user, String categoryName, AccessLevel level) async {
    // Optimistic local update.
    final updated = state.users.map((u) {
      return u.username == user.username
          ? u.copyWithPermission(categoryName, level)
          : u;
    }).toList();
    emit(state.copyWith(users: updated, clearError: true));
    try {
      await _repo.updatePermission(user, categoryName, level);
      return true;
    } catch (e) {
      // Revert on failure.
      await load();
      emit(state.copyWith(error: '$e'));
      return false;
    }
  }
}
