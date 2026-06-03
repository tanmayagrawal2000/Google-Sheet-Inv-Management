import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../../features/auth/data/auth_service.dart';

/// Builds Drive/Sheets API clients on top of the authenticated, backoff-wrapped
/// HTTP client from [AuthService]. A fresh API client is built per call so it
/// always uses current credentials; the underlying client handles refresh.
class GoogleApis {
  GoogleApis(this._auth);

  final AuthService _auth;

  Future<drive.DriveApi> driveApi() async =>
      drive.DriveApi(await _auth.authenticatedClient());

  Future<sheets.SheetsApi> sheetsApi() async =>
      sheets.SheetsApi(await _auth.authenticatedClient());
}
