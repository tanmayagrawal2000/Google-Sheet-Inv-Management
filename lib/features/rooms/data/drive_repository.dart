import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/config/app_config.dart';
import '../../../core/config/sheet_schema.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/google_apis.dart';
import '../../../shared/models/room.dart';

/// Manages the app's Drive folder and the spreadsheets ("rooms") inside it.
class DriveRepository {
  DriveRepository(this._apis);

  final GoogleApis _apis;

  static const _spreadsheetMime = 'application/vnd.google-apps.spreadsheet';
  static const _folderMime = 'application/vnd.google-apps.folder';

  String? _cachedFolderId;

  /// Finds (or creates) the app folder and caches its id.
  Future<String> ensureAppFolder() async {
    if (_cachedFolderId != null) return _cachedFolderId!;
    final api = await _apis.driveApi();
    final escaped = AppConfig.appFolderName.replaceAll("'", r"\'");
    final existing = await api.files.list(
      q: "mimeType='$_folderMime' and name='$escaped' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    final found = existing.files;
    if (found != null && found.isNotEmpty) {
      return _cachedFolderId = found.first.id!;
    }
    final created = await api.files.create(
      drive.File()
        ..name = AppConfig.appFolderName
        ..mimeType = _folderMime,
      $fields: 'id',
    );
    return _cachedFolderId = created.id!;
  }

  /// Lists all room spreadsheets in the app folder, ordered by name.
  Future<List<Room>> listRooms() async {
    final folderId = await ensureAppFolder();
    final api = await _apis.driveApi();
    final result = await api.files.list(
      q: "'$folderId' in parents and mimeType='$_spreadsheetMime' and trashed=false",
      orderBy: 'name',
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime)',
    );
    return (result.files ?? [])
        .where((f) => f.name != SheetSchema.usersSpreadsheetName)
        .map((f) => Room(
              id: f.id!,
              name: f.name ?? '(untitled)',
              modifiedTime: f.modifiedTime,
            ))
        .toList();
  }

  /// Creates a new room spreadsheet inside the app folder.
  Future<Room> createRoom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ApiFailure('Room name cannot be empty.');
    }
    final folderId = await ensureAppFolder();
    final api = await _apis.driveApi();
    final created = await api.files.create(
      drive.File()
        ..name = trimmed
        ..mimeType = _spreadsheetMime
        ..parents = [folderId],
      $fields: 'id,name,modifiedTime',
    );
    return Room(
      id: created.id!,
      name: created.name ?? trimmed,
      modifiedTime: created.modifiedTime,
    );
  }

  Future<void> renameRoom(String id, String newName) async {
    final api = await _apis.driveApi();
    await api.files.update(drive.File()..name = newName.trim(), id);
  }

  /// Moves a room to trash (recoverable from Drive).
  Future<void> deleteRoom(String id) async {
    final api = await _apis.driveApi();
    await api.files.update(drive.File()..trashed = true, id);
  }

  /// Uploads [filePath] to the app folder and returns a Drive view link.
  /// The file is made readable by anyone with the link so the URL works in Sheets.
  Future<String> uploadImage(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = filePath.split(Platform.pathSeparator).last;
    final mimeType = _mimeType(fileName);

    final folderId = await ensureAppFolder();
    final api = await _apis.driveApi();

    final created = await api.files.create(
      drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = mimeType,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: mimeType),
      $fields: 'id',
    );

    await api.permissions.create(
      drive.Permission()
        ..role = 'reader'
        ..type = 'anyone',
      created.id!,
    );

    return 'https://drive.google.com/file/d/${created.id}/view';
  }

  static String _mimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
