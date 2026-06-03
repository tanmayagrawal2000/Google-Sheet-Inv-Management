# Inventory Manager

A cross-platform (Windows / Android / iOS) Flutter app for school-style inventory
management where **Google Sheets is the database**. You sign in with your own
Google account and your data lives in your Drive.

## Model
- **Room** = a Google Spreadsheet (workbook), e.g. "Music Room". Shown as a tile.
- **Category** = a tab inside it, e.g. "Piano".
- **Item** = a row: `SNo, Detail, Manufacturer, Price, Quantity, ItemId, Notes`.
  `Quantity` is `1` for a serial-tracked unit or `N` for a bulk pool.
- **Issue log** = a hidden `_IssueLog` tab per workbook (append-only). Each
  issue/return records borrower, quantity, dates. Total / Issued / Available are
  derived in-app from the items and the open log rows.

All rooms live inside a Drive folder named **"School Inventory"**.

## Getting started
1. Do the one-time Google Cloud setup: **[docs/google_cloud_setup.md](docs/google_cloud_setup.md)**.
2. Run on Windows with your desktop OAuth credentials:
   ```powershell
   flutter run -d windows `
     --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... `
     --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
   ```
   (Or copy `run_windows.ps1.template` → `run_windows.ps1` and fill it in.)
3. Run on a phone: `flutter run -d <device>` after configuring the Android/iOS
   OAuth clients (same doc).

## Architecture
Feature-first, with `data / cubit / presentation` layers per feature:

```
lib/
  core/      config, di (get_it), network (Google API + backoff), router, theme, utils
  features/  auth | rooms | inventory | issues
  shared/    models (Equatable), cubit/data_state, widgets
```

- **State**: `flutter_bloc` (Cubits) with a generic `DataState<T>`.
- **Auth**: `google_sign_in_all_platforms` behind an `AuthService` interface
  (`lib/features/auth/data/auth_service.dart`) — swappable without touching features.
  Tokens are stored in `flutter_secure_storage`.
- **Google APIs**: `googleapis` Drive v3 + Sheets v4, all calls wrapped in a
  retry/backoff client (`lib/core/network/backoff_client.dart`) for rate-limit safety.

## Tests
```
flutter test
```
