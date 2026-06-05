import 'package:equatable/equatable.dart';

import 'user_session.dart';

/// A user record as loaded from the Users sheet, used in the management UI.
/// Unlike [UserSession] (login result), this includes the row index for writes.
class ManagedUser extends Equatable {
  const ManagedUser({
    required this.username,
    required this.isAdmin,
    required this.permissions,
    required this.rowIndex,
  });

  final String username;
  final bool isAdmin;

  /// Maps category name → access level.
  final Map<String, AccessLevel> permissions;

  /// 1-based row index in the Users sheet — needed for cell writes and deletes.
  final int rowIndex;

  ManagedUser copyWithPermission(String categoryName, AccessLevel level) =>
      ManagedUser(
        username: username,
        isAdmin: isAdmin,
        permissions: {...permissions, categoryName: level},
        rowIndex: rowIndex,
      );

  @override
  List<Object?> get props => [username, isAdmin, permissions, rowIndex];
}
