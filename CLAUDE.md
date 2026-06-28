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

**Android build issues**: if the device shows stale UI after `flutter run`, run `flutter clean && flutter pub get`, uninstall the app from the device, then reinstall via `.\run_android.ps1`.

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
    auth/         GsiAuthService, AuthCubit, UserSessionCubit, UserManagementCubit,
                  SecureTokenStore, UserRepository, SignInScreen, CustomSignInScreen,
                  UserManagementScreen
    rooms/        DriveRepository, RoomsCubit, RoomsScreen
    inventory/    SheetsRepository, CatalogRepository, DamageRepository,
                  RoomCubit, CategoryCubit, ItemDetailCubit, DamageLogCubit,
                  screens + widgets (incl. RepairItemSheet, ReturnItemSheet,
                  DamageItemSheet, DiscardItemSheet)
    issues/       IssueRepository, IssuesCubit, IssuesScreen
  shared/
    models/       Room, InventoryItem, IssueRecord, DamageRecord,
                  UserSession, ManagedUser (all Equatable where applicable)
    cubit/        DataState<T> (generic async state)
    widgets/      DataView (generic loading/error/ready/empty + LinearProgressIndicator)
```

## Authentication — two layers

1. **Google OAuth (master account)** — runs silently on launch via stored tokens (`SecureTokenStore`). Only shows the Google OAuth screen if no token exists (first install / after Google sign-out). End-users never see this.

2. **Custom session (user login)** — username/password checked against the `Users` Google Sheet once at login. Permissions cached in `UserSessionCubit` for the session. Cleared on sign-out; never re-fetched mid-session.

**Router states:**

| Google auth | User session | Route |
|---|---|---|
| not signed in | — | `/sign-in` (Google OAuth, admin setup only) |
| signed in | none | `/custom-login` (username/password) |
| signed in | active | `/` (main app, filtered by permissions) |

## Users Sheet (custom auth)

Spreadsheet named `Users` in the "School Inventory" Drive folder. Excluded from the category list.

| Col | Content |
|---|---|
| A | Username |
| B | Password (plain text) |
| C | Admin (TRUE/FALSE) |
| D+ | One column per category name → `write` / `read` / `none` |

- Admin=TRUE overrides all per-category permissions (full write everywhere)
- Columns D+ are managed automatically: added when a category is created, removed when deleted, renamed when renamed
- Default credentials on first launch: `admin` / `admin123` — change immediately
- Formatting: bold header row, per-column dropdowns (write/read/none), row 1 frozen

**Permission checking** — `UserSession.canRead(categoryName)` / `canWrite(categoryName)`:
- Checked once at login, cached for the session
- To update permissions: edit the Users sheet, then the user must log out and back in
- Admin-only UI: "Manage Users" icon in the Categories AppBar (`UserManagementScreen`)

## UI terminology → Google entity

| UI term | Google entity | Notes |
|---|---|---|
| **Category** | Spreadsheet (workbook) | In "School Inventory" Drive folder; name may have emoji prefix e.g. `"🎵 Music"` |
| **Section** | Sheet tab | Visible tab inside a category, e.g. "Piano" |
| **Item** | Row in a section tab | 10 data columns + 4 stat columns + summary block |
| **Issue log** | `_IssueLog` tab | Append-only; one row per issue / partial-return / full-return |
| **Damage log** | `_DamageLog` tab | Append-only; one row per damage / partial-repair / full-repair / discard |

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

**Stat columns K–N (indices 10–13) — written with static values, never read back:**

| Col | Index | Value |
|---|---|---|
| K | 10 | Total (= Quantity) |
| L | 11 | Issued |
| M | 12 | Damaged |
| N | 13 | Available (= Total − Issued − Damaged) |

**Summary block** — always `SheetSchema.summaryLabelCol` / `summaryValueCol` (computed as `formulaColAvailable + 2/3`; currently P–Q). Written once at section creation, never re-written. Uses whole-column `=SUM(K:K)` formulas. `appendRow` uses `OVERWRITE` so the summary is never displaced.

Always use `SheetSchema.*` constants — never hard-code column positions. `summaryLabelCol` / `summaryValueCol` are `get` properties (not `const`) so they shift if columns are added.

## Log tab schemas

**`_IssueLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, Borrower, DateIssued, ExpectedReturn, DateReturned, Status`
- Status: `Open` / `Returned` (capitalised, parsing case-insensitive)
- Status dropdown applied per-row via `applyStatusDropdownToRow` on each append
- Conditional colours set once at creation (`formatIssueLog`); **not re-applied per write**
- Formatting: bold header, yellow Status cell = `Open`, green = `Returned`

**`_DamageLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, DamagedDate, Details, RepairDate, Status`
- Status: `Damaged` / `Repaired` / `Discarded` (capitalised, parsing case-insensitive)
- `RepairDate` also used as discard date for `Discarded` records
- Status dropdown applied per-row; conditional colours set once at creation
- Formatting: bold header, red = `Damaged`, green = `Repaired`, gray = `Discarded`

## In-app derived counts

`InventoryItem.issued` and `.damaged` are **not** stored in the item row — computed at load time:
- `issued` = sum of `Quantity` from `_IssueLog` rows where `Status == "Open"` and `ItemId` matches
- `damaged` = sum of `Quantity` from `_DamageLog` rows where `Status == "Damaged"` and `ItemId` matches
- `discarded` rows are excluded from damaged count; instead they permanently reduce the item's `Quantity`
- `available` = `quantity − issued − damaged` (clamped ≥ 0)

## Mutations and sheet stat refresh

After every mutation that changes counts, the cubit calls `_refreshSheetStats`:
1. Uses already-loaded items in state (no extra API call)
2. `refreshSheetStats` → `batchWriteItemStats` writes K–N for all items in that section

| Cubit | Mutations that refresh stats |
|---|---|
| `CategoryCubit` | `issue`, `registerDamage`, `addQty` |
| `IssuesCubit` | `returnIssue` (uses `record.categoryTab`) |
| `DamageLogCubit` | `repairDamage`, `discardDamage` (uses `record.categoryTab`) |
| `ItemDetailCubit` | `returnIssue`, `repairDamage`, `discardDamage` |

## Discard flow

Discarding permanently removes items from inventory:
1. Damage record marked `Discarded` in `_DamageLog`
2. Item's `Quantity` reduced by discarded amount (`loadSingleItem` → 1 read, then `updateItemQty`)
3. K–N stats refreshed

`damagedByItem` excludes `Discarded` rows — they reduce `Quantity` directly so they don't need to stay in the damaged count.

## Google Sheets API quota and call counts

**Quota:** 300 read requests per minute per user.

Optimised call counts per action (after quota optimisations):

| Action | Reads | Writes |
|---|---|---|
| Open section | 5 | 0 |
| Open Item Detail | **5** | 0 |
| Issue item | 9 | 2 |
| Register damage | 7 | 1 |
| Add item | 7 | 1 |
| Discard (ItemDetail) | **6** | 2 |

**Key optimisations applied:**
- `ItemDetailCubit.load()`: reads one item row (1 read) + computes issued/damaged from already-fetched logs — no `loadCategory` call (saves 4 reads)
- `formatIssueLog` / `formatDamageLog` removed from per-write flow — conditional colours are permanent in Sheets once set at creation
- `unboldDataRows` removed — `OVERWRITE` mode only writes values; `_applyHeaderFormat` pre-sets rows 2+ to non-bold at sheet creation and that format persists

## ItemDetailCubit.load() design

Runs 3 parallel reads (5 API calls total):
1. `_issues.readLog` → 2 reads (`_allTabTitles` + `readRange(_IssueLog)`)
2. `_damage.readLog` → 2 reads (`_allTabTitles` + `readRange(_DamageLog)`)
3. `_catalog.loadSingleItem` → 1 read (just the item's row in the section tab)

Issued/damaged counts are computed in-memory from the already-fetched logs. No `loadCategory` needed.

`item_detail_screen.dart` shows static fields (name, image, metadata) from `cubit.item` immediately, and live counts from `state.data?.item` once loaded (shows `LinearProgressIndicator` for counts during load).

## Sheet initialization

On `RoomsCubit.createRoom`, `SheetsRepository.initializeSpreadsheet` runs immediately:
1. Bold header / un-bold data / freeze row 1 on all existing section tabs + write summary block
2. `ensureIssueLog` → creates `_IssueLog` with headers + `formatIssueLog`
3. `ensureDamageLog` → creates `_DamageLog` with headers + `formatDamageLog`

`createCategory` (Add section): writes item/formula headers + summary block + header format.

`ensureHeaders` is called before every `appendRow` in `addItem`.

## Delete section flow

`SheetsRepository.deleteSection`: 2 round trips.
1. Parallel: `spreadsheets.get` (sheetIds) + `batchGet` (both log tabs)
2. Single `batchUpdate`: delete matching log rows (by `CategoryTab`, high→low) + delete section tab

## State management

Cubits (flutter_bloc) wrap `DataState<T>` with `status`, `data`, `error`, `refreshing`. Rules:
- **Emit `refreshing: true` before every mutation** so `DataView` shows `LinearProgressIndicator` immediately.
- After any mutation, call `load()` to re-derive all counts from source data.
- Cubits are instantiated at the widget tree via `BlocProvider`; they pull dependencies from `get_it`.

## CategoryScreen reload on pop

`_CategoryViewState` reads `CategoryCubit` before pushing to Item Detail:
```dart
final cubit = context.read<CategoryCubit>();
await context.push('/room/.../item', extra: item);
cubit.load(); // go_router push() completes when popped
```
This ensures the category list shows fresh counts after any repair/discard/return done in Item Detail.

## Dependency injection

`configureDependencies(SharedPreferences prefs)` called from `main()`. All singletons in `lib/core/di/injector.dart`. Cubits are NOT in get_it (exception: `UserSessionCubit` and `UserManagementCubit` are registered as singletons/factories since they're needed across the auth layer).

## Auth flow

`GsiAuthService` (`google_sign_in_all_platforms`):
- **Desktop / Web**: Web application OAuth client. `clientId` via `--dart-define=GOOGLE_DESKTOP_CLIENT_ID`. Desktop also needs `GOOGLE_DESKTOP_CLIENT_SECRET`.
- **Mobile**: native account picker. Same Web client ID via `--dart-define=GOOGLE_MOBILE_CLIENT_ID`. No secret needed.

Tokens persisted via `flutter_secure_storage`. go_router redirect guards all routes via both `AuthCubit.state.status` AND `UserSessionCubit.state.isAuthenticated`.

## Google API calls

`GoogleApis` → fresh `DriveApi` / `SheetsApi` per call → `BackoffClient` (retries 429/5xx, exponential backoff + jitter, honors `Retry-After`). Sheets quota: 300 read req/min per user.

## Routes

| Path | Screen |
|---|---|
| `/splash` | Spinner while auth resolves |
| `/sign-in` | `SignInScreen` (Google OAuth, admin setup only) |
| `/custom-login` | `CustomSignInScreen` (username/password) |
| `/` | `RoomsScreen` — category grid; admin sees 👤 Manage Users icon |
| `/users` | `UserManagementScreen` — add/delete users, set per-category permissions |
| `/room/:id` | `RoomScreen` — section list; "Logs" popup → Issue Log or Damage Log |
| `/room/:id/category/:tab` | `CategoryScreen` — items with filterable Total/Issued/Damaged/Available summary bar |
| `/room/:id/category/:tab/item` | `ItemDetailScreen` — detail + tappable issue/damage history (`extra: InventoryItem`, `tab` in path) |
| `/room/:id/log` | `IssuesScreen` — issue/return log with partial return |
| `/room/:id/damage-log` | `DamageLogScreen` — damage/repair/discard log |

## Conventions

- **No hard-coded column indices** — always use `SheetSchema.*` constants.
- **`summaryLabelCol` / `summaryValueCol` are `get` (not `const`)** — auto-shift when columns are added.
- **Credentials via `--dart-define`** — never embed in source; read via `AppConfig`.
- **`AuthService` is the only dependency on the sign-in package** — keep features decoupled.
- **Models are immutable Equatable** — use `copyWith` for mutations.
- **Emit `refreshing: true` before every mutation** — `DataView` shows `LinearProgressIndicator` immediately.
- **Stat columns (K–N) are write-only** — app always derives counts from raw log rows, never reads K–N back.
- **`appendRow` uses `OVERWRITE`** — never `INSERT_ROWS`; physical row insertion displaces the summary block.
- **No `unboldDataRows` after append** — `OVERWRITE` writes values only; `_applyHeaderFormat` pre-sets rows 2+ to non-bold permanently.
- **No `formatIssueLog`/`formatDamageLog` per write** — conditional colours are permanent once set at sheet creation; only `applyStatusDropdownToRow` runs per new row.
- **Category names store emoji prefix** — e.g. `"🎵 Music"`. Use `_leadingEmoji()` / `_displayName()` in `rooms_screen.dart` to split.
- **Colors**: Issued = `scheme.tertiary`, Damaged = `scheme.error`, Available = `scheme.primary`.
- **Formatting failures are silently swallowed** — sheet formatting is cosmetic, must never break app flow.
- **Status values are capitalised** — `"Open"`, `"Returned"`, `"Damaged"`, `"Repaired"`, `"Discarded"`. Parsing is case-insensitive for backward compatibility.
- **Item Detail static vs live split** — `cubit.item` for static fields (name/image/metadata), `state.data?.item` for live counts; never show stale count numbers.
