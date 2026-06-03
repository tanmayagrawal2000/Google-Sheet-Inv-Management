/// Static configuration for the app: OAuth client details, API scopes, and the
/// name of the Drive folder that holds all "room" spreadsheets.
///
/// The OAuth client IDs/secret are filled in after creating credentials in the
/// Google Cloud Console (see docs/google_cloud_setup.md). For installed/desktop
/// OAuth clients the "secret" is not actually secret (per RFC 8252) and is safe
/// to ship in a public client.
class AppConfig {
  AppConfig._();

  /// Drive folder that contains every room spreadsheet. Created on first run.
  static const String appFolderName = 'School Inventory';

  /// Desktop (installed-app) OAuth client used for the loopback flow on
  /// Windows / Linux / macOS desktop.
  static const String desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue: '',
  );
  static const String desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Mobile (Android/iOS) client id, when needed by the platform sign-in flow.
  static const String mobileClientId = String.fromEnvironment(
    'GOOGLE_MOBILE_CLIENT_ID',
    defaultValue: '',
  );

  /// OAuth scopes. `drive.file` lets the app create and access only the files
  /// it creates (the app folder + room spreadsheets) without a restricted-scope
  /// security review. `spreadsheets` grants read/write to those sheets.
  static const List<String> scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  static bool get hasDesktopCredentials => desktopClientId.isNotEmpty;

  /// Mobile client id or null when not configured (mobile platforms usually
  /// read config from google-services.json / Info.plist instead).
  static String? get mobileClientIdOrNull =>
      mobileClientId.isEmpty ? null : mobileClientId;
}
