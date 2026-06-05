import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../../../core/config/sheet_schema.dart';
import '../../../core/network/google_apis.dart';
import '../../../shared/models/managed_user.dart';
import '../../../shared/models/user_session.dart';
import '../../rooms/data/drive_repository.dart';

/// Manages the "Users" Google Spreadsheet that backs custom authentication
/// and per-category permissions.
///
/// The spreadsheet lives in the same Drive folder as the categories and is
/// excluded from the category list. Schema:
///   Row 1: Username | Password | Admin | CategoryName1 | CategoryName2 | …
///   Row 2+: user rows
/// Cell values for category columns: "write", "read", or "" (no access).
class UserRepository {
  UserRepository(this._apis, this._drive);

  final GoogleApis _apis;
  final DriveRepository _drive;

  String? _cachedSpreadsheetId;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Verifies [username]/[password] against the Users sheet and returns a
  /// [UserSession] with cached permissions, or null on failure.
  Future<UserSession?> authenticate(
      String username, String password) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return null;

    final headers = _cells(rows[0]);
    for (var i = 1; i < rows.length; i++) {
      final row = _cells(rows[i]);
      if (row.isEmpty) continue;
      if (row[SheetSchema.usersColUsername].trim().toLowerCase() !=
          username.trim().toLowerCase()) {
        continue;
      }
      if (row[SheetSchema.usersColPassword].trim() != password.trim()) {
        return null; // username matched but wrong password
      }
      final isAdmin =
          row.length > SheetSchema.usersColAdmin &&
          row[SheetSchema.usersColAdmin].trim().toLowerCase() == 'true';

      final perms = <String, AccessLevel>{};
      for (var c = SheetSchema.usersFirstCatCol;
          c < headers.length;
          c++) {
        final catName = headers[c].trim();
        if (catName.isEmpty) continue;
        final val = c < row.length ? row[c].trim().toLowerCase() : '';
        if (val == 'write') {
          perms[catName] = AccessLevel.write;
        } else if (val == 'read') {
          perms[catName] = AccessLevel.read;
        } else {
          perms[catName] = AccessLevel.none;
        }
      }

      return UserSession(
        username: row[SheetSchema.usersColUsername].trim(),
        isAdmin: isAdmin,
        permissions: perms,
      );
    }
    return null; // username not found
  }

  /// Adds a column for [categoryName] to the Users sheet.
  /// Admin users automatically get "write"; all others get "" (no access).
  Future<void> addCategoryColumn(String categoryName) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return;

    final headers = _cells(rows[0]);
    final newColIndex = headers.length; // 0-based

    final colLetter = _colLetter(newColIndex);
    final api = await _apis.sheetsApi();

    // Write the header.
    await _writeCell(api, ssId, '${SheetSchema.usersSheetTab}!$colLetter'
        '1:${colLetter}1', [[categoryName]]);

    // Write per-user values: "write" for admins, "" for others.
    for (var i = 1; i < rows.length; i++) {
      final row = _cells(rows[i]);
      if (row.isEmpty) continue;
      final isAdmin = row.length > SheetSchema.usersColAdmin &&
          row[SheetSchema.usersColAdmin].trim().toLowerCase() == 'true';
      final rowNumber = i + 1; // 1-based
      await _writeCell(api, ssId,
          '${SheetSchema.usersSheetTab}!$colLetter$rowNumber:$colLetter$rowNumber',
          [[isAdmin ? 'write' : '']]);
    }
  }

  /// Removes the column for [categoryName] from the Users sheet.
  Future<void> removeCategoryColumn(String categoryName) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return;

    final headers = _cells(rows[0]);
    final colIndex = headers.indexWhere(
        (h) => h.trim() == categoryName.trim());
    if (colIndex < 0) return; // column not found

    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets
        .get(ssId, $fields: 'sheets.properties(sheetId,title)');
    final sheetId = (ss.sheets ?? [])
        .where((s) => s.properties?.title == SheetSchema.usersSheetTab)
        .firstOrNull
        ?.properties
        ?.sheetId;
    if (sheetId == null) return;

    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'COLUMNS',
              startIndex: colIndex,
              endIndex: colIndex + 1,
            ),
          ),
        ),
      ]),
      ssId,
    );
  }

  /// Renames the column header from [oldName] to [newName] in the Users sheet.
  Future<void> renameCategoryColumn(
      String oldName, String newName) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return;

    final headers = _cells(rows[0]);
    final colIndex =
        headers.indexWhere((h) => h.trim() == oldName.trim());
    if (colIndex < 0) return;

    final colLetter = _colLetter(colIndex);
    final api = await _apis.sheetsApi();
    await _writeCell(api, ssId,
        '${SheetSchema.usersSheetTab}!$colLetter'
            '1:${colLetter}1',
        [[newName]]);
  }

  // ── User management API ─────────────────────────────────────────────────────

  /// Returns all users with their permissions and row indices.
  Future<({List<ManagedUser> users, List<String> categoryNames})>
      loadAllUsers() async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) {
      return (users: <ManagedUser>[], categoryNames: <String>[]);
    }

    final headers = _cells(rows[0]);
    final catNames = headers
        .skip(SheetSchema.usersFirstCatCol)
        .where((h) => h.trim().isNotEmpty)
        .toList();

    final users = <ManagedUser>[];
    for (var i = 1; i < rows.length; i++) {
      final row = _cells(rows[i]);
      if (row.isEmpty) continue;
      final username =
          row.length > SheetSchema.usersColUsername
              ? row[SheetSchema.usersColUsername].trim()
              : '';
      if (username.isEmpty) continue;
      final isAdmin =
          row.length > SheetSchema.usersColAdmin &&
          row[SheetSchema.usersColAdmin].trim().toLowerCase() == 'true';

      final perms = <String, AccessLevel>{};
      for (var c = SheetSchema.usersFirstCatCol;
          c < headers.length;
          c++) {
        final catName = headers[c].trim();
        if (catName.isEmpty) continue;
        final val = c < row.length ? row[c].trim().toLowerCase() : '';
        perms[catName] = val == 'write'
            ? AccessLevel.write
            : val == 'read'
                ? AccessLevel.read
                : AccessLevel.none;
      }
      users.add(ManagedUser(
        username: username,
        isAdmin: isAdmin,
        permissions: perms,
        rowIndex: i + 1, // 1-based
      ));
    }
    return (users: users, categoryNames: catNames);
  }

  /// Appends a new user row. [permissions] maps category name → access level
  /// for categories already in the Users sheet.
  Future<void> addUser(
    String username,
    String password, {
    bool isAdmin = false,
    Map<String, AccessLevel> permissions = const {},
  }) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return;

    final headers = _cells(rows[0]);
    final catNames =
        headers.skip(SheetSchema.usersFirstCatCol).toList();
    final newRow = [
      username.trim(),
      password,
      isAdmin ? 'TRUE' : 'FALSE',
      for (final cat in catNames)
        _accessString(permissions[cat.trim()] ?? AccessLevel.none),
    ];

    final api = await _apis.sheetsApi();
    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [newRow]),
      ssId,
      SheetSchema.usersSheetTab,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'OVERWRITE',
    );
  }

  /// Deletes the user row at [user.rowIndex] from the sheet.
  Future<void> deleteUser(ManagedUser user) async {
    final ssId = await _ensureUsersSpreadsheet();
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets
        .get(ssId, $fields: 'sheets.properties(sheetId,title)');
    final sheetId = (ss.sheets ?? [])
        .where((s) => s.properties?.title == SheetSchema.usersSheetTab)
        .firstOrNull
        ?.properties
        ?.sheetId;
    if (sheetId == null) return;

    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: user.rowIndex - 1,
              endIndex: user.rowIndex,
            ),
          ),
        ),
      ]),
      ssId,
    );
  }

  /// Updates the permission for [user] on [categoryName] to [level].
  Future<void> updatePermission(
    ManagedUser user,
    String categoryName,
    AccessLevel level,
  ) async {
    final ssId = await _ensureUsersSpreadsheet();
    final rows = await _readAll(ssId);
    if (rows.isEmpty) return;

    final headers = _cells(rows[0]);
    final colIndex =
        headers.indexWhere((h) => h.trim() == categoryName.trim());
    if (colIndex < 0) return;

    final colLetter = _colLetter(colIndex);
    final api = await _apis.sheetsApi();
    await _writeCell(
      api,
      ssId,
      '${SheetSchema.usersSheetTab}!$colLetter${user.rowIndex}:'
          '$colLetter${user.rowIndex}',
      [[_accessString(level)]],
    );
  }

  static String _accessString(AccessLevel level) => switch (level) {
        AccessLevel.write => 'write',
        AccessLevel.read => 'read',
        AccessLevel.none => '',
      };

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Finds or creates the "Users" spreadsheet and returns its ID.
  Future<String> _ensureUsersSpreadsheet() async {
    if (_cachedSpreadsheetId != null) return _cachedSpreadsheetId!;

    final folderId = await _drive.ensureAppFolder();
    final driveApi = await _apis.driveApi();
    const mime = 'application/vnd.google-apps.spreadsheet';

    // Search for existing Users spreadsheet.
    final existing = await driveApi.files.list(
      q: "'$folderId' in parents and "
          "mimeType='$mime' and "
          "name='${SheetSchema.usersSpreadsheetName}' and "
          "trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return _cachedSpreadsheetId = existing.files!.first.id!;
    }

    // Create the spreadsheet.
    final created = await driveApi.files.create(
      drive.File()
        ..name = SheetSchema.usersSpreadsheetName
        ..mimeType = mime
        ..parents = [folderId],
      $fields: 'id',
    );
    final ssId = created.id!;
    _cachedSpreadsheetId = ssId;

    // Rename the default tab to "Users".
    final sheetsApi = await _apis.sheetsApi();
    final ss = await sheetsApi.spreadsheets
        .get(ssId, $fields: 'sheets.properties(sheetId,title)');
    final defaultSheetId =
        (ss.sheets ?? []).firstOrNull?.properties?.sheetId ?? 0;

    await sheetsApi.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
            properties: sheets.SheetProperties(
              sheetId: defaultSheetId,
              title: SheetSchema.usersSheetTab,
            ),
            fields: 'title',
          ),
        ),
      ]),
      ssId,
    );

    // Build initial header + admin row with all existing categories.
    final existingRooms = await _drive.listRooms();
    final catNames =
        existingRooms.map((r) => r.name).toList();

    final headers = [
      'Username',
      'Password',
      'Admin',
      ...catNames,
    ];
    final adminRow = [
      'admin',
      'admin123',
      'TRUE',
      for (final _ in catNames) 'write',
    ];

    await _writeCell(sheetsApi, ssId,
        '${SheetSchema.usersSheetTab}!A1:${_colLetter(headers.length - 1)}2',
        [headers, adminRow]);

    return ssId;
  }

  Future<List<List<Object?>>> _readAll(String ssId) async {
    final api = await _apis.sheetsApi();
    final resp = await api.spreadsheets.values
        .get(ssId, SheetSchema.usersSheetTab);
    return resp.values ?? const [];
  }

  Future<void> _writeCell(sheets.SheetsApi api, String ssId, String range,
      List<List<Object?>> values) async {
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: values),
      ssId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  List<String> _cells(List<Object?> row) =>
      row.map((c) => c?.toString() ?? '').toList();

  /// Converts a 0-based column index to its spreadsheet letter (A, B, … Z, AA, …).
  static String _colLetter(int index) {
    var n = index;
    final letters = <int>[];
    do {
      letters.add(65 + (n % 26));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(letters.reversed);
  }
}
