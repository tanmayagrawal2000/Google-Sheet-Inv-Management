# Inventory Manager — CLAUDE.md

## What this project is

A cross-platform Flutter app (Windows / Android / iOS / Chrome) for school inventory management where **Google Sheets is the database**. Users sign in with Google; their data lives in their own Drive. There is no backend — all reads and writes go directly to the Sheets and Drive APIs.

## Running the app

Use the pre-filled scripts (gitignored, never commit):

| Platform | Script |
|---|---|
| Windows | `.\run_windows.ps1` |
| Android | `.\run_android.ps1` |
| Chrome | `.\run_chrome.ps1` |

All scripts pass credentials via `--dart-define`. Google Cloud setup is documented in `docs/google_cloud_setup.md`.

**Android**: requires an Android OAuth credential (SHA-1 + package `com.manage.inventory`). The Web client ID is passed as `GOOGLE_MOBILE_CLIENT_ID` — no secret needed.

**Chrome**: requires `http://localhost` added to Authorized JavaScript Origins on the Web application OAuth client.

**Tests:** `flutter test`

## Architecture

Feature-first, with `data / cubit / presentation` sub-layers per feature:

```
lib/
  core/
    config/       AppConfig (dart-define credentials), SheetSchema (column layout)
    di/           injector.dart — get_it wiring; configureDependencies(SharedPreferences)
    errors/       failures.dart — AppFailure hierarchy
    network/      GoogleApis (Drive+Sheets clients), BackoffClient (retry/429 handling)
    router/       app_router.dart (go_router + auth gate), GoRouterRefreshStream
    theme/        AppTheme, ThemeCubit (light/dark/system, persisted via shared_preferences)
    utils/        a1.dart (A1 notation helpers)
  features/
    auth/         GsiAuthService, AuthCubit, SecureTokenStore, SignInScreen
    rooms/        DriveRepository, RoomsCubit, RoomsScreen
    inventory/    SheetsRepository, CatalogRepository, DamageRepository,
                  RoomCubit, CategoryCubit, ItemDetailCubit, screens + widgets
    issues/       IssueRepository, IssuesCubit, IssuesScreen
  shared/
    models/       Room, InventoryItem, IssueRecord, DamageRecord (all Equatable)
    cubit/        DataState<T> (generic async state)
    widgets/      DataView (generic loading/error/ready/empty + LinearProgressIndicator)
```

## UI terminology → Google entity

| UI term | Google entity | Notes |
|---|---|---|
| **Category** | Spreadsheet (workbook) | In "School Inventory" Drive folder; name may have emoji prefix e.g. `"🎵 Music"` |
| **Section** | Sheet tab | Visible tab inside a category, e.g. "Piano" |
| **Item** | Row in a section tab | 10 data columns + 4 formula columns |
| **Issue log** | `_IssueLog` tab | Visible, append-only; one row per issue/return |
| **Damage log** | `_DamageLog` tab | Visible, append-only; one row per damage event |

## Item column layout

**Data columns A–J (indices 0–9) — read and written by app:**

| Col | Index | Name |
|---|---|---|
| A | 0 | SNo |
| B | 1 | Detail |
| C | 2 | Firm Name |
| D | 3 | Price |
| E | 4 | Quantity |
| F | 5 | ItemId |
| G | 6 | Notes |
| H | 7 | ImageUrl |
| I | 8 | Bill No |
| J | 9 | Bill Date |

**Formula columns K–N (indices 10–13) — written for human visibility, never read by app:**

| Col | Index | Formula |
|---|---|---|
| K | 10 | Total = `=E{row}` |
| L | 11 | Issued = SUMPRODUCT over `_IssueLog` |
| M | 12 | Damaged = SUMPRODUCT over `_DamageLog` |
| N | 13 | Available = `=K{row}-L{row}-M{row}` |

Always use `SheetSchema.*` constants — never hard-code column positions.

## Log tab schemas

**`_IssueLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, Borrower, DateIssued, ExpectedReturn, DateReturned, Status`
- Status values: `open` / `returned`
- Formatting: blue header, yellow rows when `open`, green rows when `returned`

**`_DamageLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, DamagedDate, Details`
- Formatting: blue header, amber tint on all data rows

## In-app derived counts

`InventoryItem.issued` and `.damaged` are **not** stored in the item row — they are computed at load time:
- `issued` = sum of open `_IssueLog` rows matching `itemId`
- `damaged` = sum of all `_DamageLog` rows matching `itemId`
- `available` = `quantity - issued - damaged` (clamped to 0)

## Sheet initialization invariants

These must hold for every section tab — violations cause items to land in row 1 and be skipped:

1. **Header row** must be written to row 1 before any item is appended.
   - `SheetsRepository.ensureHeaders()` is called before every `appendRow` in `addItem` and for all auto-created tabs in `RoomsCubit.createRoom`.
2. **`_IssueLog` and `_DamageLog`** must exist before `writeItemFormulas` / `batchWriteItemFormulas` run, otherwise SUMPRODUCT formulas reference non-existent tabs and enter a permanent `#REF!` state.
   - Both `ensureIssueLog` and `ensureDamageLog` are called in `CatalogRepository.addItem`.
3. **`batchWriteItemFormulas`** is called at the end of every `loadCategory` to repair any stale formula cells in one batch API call.

## Sheet formatting

Applied automatically on tab creation (cosmetic, failures are silently ignored):
- All section tabs: bold white-on-blue header, row 1 frozen
- `_IssueLog`: same header + conditional row colours (yellow = open, green = returned)
- `_DamageLog`: same header + amber tint on all data rows

Formatting is **not** retroactively applied to existing tabs.

## State management

Cubits (flutter_bloc) wrap `DataState<T>` with `status`, `data`, `error`, `refreshing`. Rules:
- **Emit `refreshing: true` before every mutation** so `DataView` shows `LinearProgressIndicator` immediately.
- After any mutation, call `load()` to re-derive all counts from source data.
- Cubits are instantiated at the widget tree via `BlocProvider`; they pull dependencies from `get_it`.

## Dependency injection

`configureDependencies(SharedPreferences prefs)` called from `main()` after `await SharedPreferences.getInstance()`. All singletons registered in `lib/core/di/injector.dart`. Cubits are NOT in get_it.

## Auth flow

`GsiAuthService` (`google_sign_in_all_platforms`):
- **Desktop / Web**: Web application OAuth client. `clientId` required via `--dart-define=GOOGLE_DESKTOP_CLIENT_ID`. Desktop also needs `GOOGLE_DESKTOP_CLIENT_SECRET`.
- **Mobile**: native account picker. Same Web client ID via `--dart-define=GOOGLE_MOBILE_CLIENT_ID`. No secret needed.

Tokens persisted via `flutter_secure_storage`. go_router redirect guards all routes via `AuthCubit.state.status`.

## Google API calls

`GoogleApis` → fresh `DriveApi` / `SheetsApi` per call → `BackoffClient` wraps HTTP (retries 429/5xx, exponential backoff + jitter, honors `Retry-After`). Sheets quota: 60 req/min per user.

## Routes

| Path | Screen |
|---|---|
| `/splash` | Spinner while auth resolves |
| `/sign-in` | `SignInScreen` |
| `/` | `RoomsScreen` — category grid with emoji/initial avatars |
| `/room/:id` | `RoomScreen` — section list with colored initial avatars |
| `/room/:id/category/:tab` | `CategoryScreen` — items with Total/Issued/Damaged/Available stats |
| `/room/:id/category/:tab/item` | `ItemDetailScreen` — item detail + issue & damage history (`extra: InventoryItem`) |
| `/room/:id/log` | `IssuesScreen` — full issue/return log |

## Key packages

| Package | Purpose |
|---|---|
| `flutter_bloc` | Cubit state management |
| `get_it` | Service locator / DI |
| `go_router` | Declarative routing with auth redirect |
| `googleapis` | Drive v3 + Sheets v4 typed clients |
| `google_sign_in_all_platforms` | OAuth for desktop, mobile, and web |
| `flutter_secure_storage` | Token persistence |
| `shared_preferences` | Theme mode persistence |
| `image_picker` | Photo attachment for items |
| `equatable` | Value equality on models and states |
| `uuid` | Item and log IDs |
| `http` | HTTP base layer (wrapped by BackoffClient) |

## Conventions

- **No hard-coded column indices** — always use `SheetSchema.*` constants.
- **Credentials via `--dart-define`** — never embed in source; read via `AppConfig`.
- **`AuthService` is the only dependency on the sign-in package** — keep features decoupled.
- **Models are immutable Equatable** — use `copyWith` for mutations.
- **Emit `refreshing: true` before every mutation** — `DataView` shows `LinearProgressIndicator` immediately.
- **Formula columns (K–N) are write-only** — app always derives counts from raw log rows, never reads formula columns.
- **Category names store emoji prefix** — e.g. `"🎵 Music"`. Use `_leadingEmoji()` / `_displayName()` in `rooms_screen.dart` to split.
- **Colors**: Issued = `scheme.tertiary`, Damaged = `scheme.error`, Available = `scheme.primary`.
- **Formatting failures are silently swallowed** — sheet formatting is cosmetic and must never break app flow.
