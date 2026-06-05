import 'package:equatable/equatable.dart';

enum AccessLevel { none, read, write }

class UserSession extends Equatable {
  const UserSession({
    required this.username,
    required this.isAdmin,
    required this.permissions,
  });

  final String username;
  final bool isAdmin;

  /// Maps category name (exact Drive spreadsheet name) to access level.
  final Map<String, AccessLevel> permissions;

  bool canRead(String categoryName) =>
      isAdmin ||
      (permissions[categoryName] ?? AccessLevel.none) != AccessLevel.none;

  bool canWrite(String categoryName) =>
      isAdmin || permissions[categoryName] == AccessLevel.write;

  @override
  List<Object?> get props => [username, isAdmin, permissions];
}
