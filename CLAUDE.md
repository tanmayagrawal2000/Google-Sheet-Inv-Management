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
    auth/         GsiAuthService, AuthCubit, SecureTokenStore, SignInScreen
    rooms/        DriveRepository, RoomsCubit, RoomsScreen
    inventory/    SheetsRepository, CatalogRepository, DamageRepository,
                  RoomCubit, CategoryCubit, ItemDetailCubit, DamageLogCubit,
                  screens + widgets (incl. RepairItemSheet, ReturnItemSheet)
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
| **Item** | Row in a section tab | 10 data columns + 4 stat columns |
| **Issue log** | `_IssueLog` tab | Append-only; one row per issue/partial-return/full-return |
| **Damage log** | `_DamageLog` tab | Append-only; one row per damage/partial-repair/full-repair |

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

**Stat columns K–N (indices 10–13) — written with static values by the app after every mutation, never read back:**

| Col | Index | Value |
|---|---|---|
| K | 10 | Total (= Quantity) |
| L | 11 | Issued |
| M | 12 | Damaged |
| N | 13 | Available (= Total − Issued − Damaged) |

`writeItemFormulas(spreadsheetId, tab, rowIndex, quantity)` writes `[qty, 0, 0, qty]` when an item is first added. `batchWriteItemStats` / `refreshSheetStats` pushes the current in-memory counts to K–N after every mutation (issue, return, damage, repair, add qty). The Sheets API does **not** trigger cross-tab SUMPRODUCT recalculation reliably, so static values are used instead of formulas.

Always use `SheetSchema.*` constants — never hard-code column positions.

## Log tab schemas

**`_IssueLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, Borrower, DateIssued, ExpectedReturn, DateReturned, Status`
- Status values: `Open` / `Returned` (capitalised)
- `IssueRecord.isOpen` is case-insensitive (`status.toLowerCase() != "returned"`)
- Status column has a dropdown (data validation) applied per-row when each issue is appended
- Formatting: bold header row, yellow Status cell when `Open`, green when `Returned`

**`_DamageLog`:** `LogId, CategoryTab, ItemId, ItemDetail, Quantity, DamagedDate, Details, Status`
- Status values: `Damaged` / `Repaired` (capitalised)
- `damagedByItem` counts only rows where `status == "Damaged"`
- Formatting: bold header row only

## In-app derived counts

`InventoryItem.issued` and `.damaged` are **not** stored in the item row — computed at load time:
- `issued` = sum of `Quantity` from `_IssueLog` rows where `Status == "Open"` and `ItemId` matches
- `damaged` = sum of `Quantity` from `_DamageLog` rows where `Status == "Damaged"` and `ItemId` matches
- `available` = `quantity − issued − damaged` (clamped ≥ 0)

## Mutations and sheet stat refresh

After every mutation that changes counts, the cubit calls `_refreshSheetStats` which:
1. `loadCategory` → fresh in-memory items with correct counts
2. `refreshSheetStats` → `batchWriteItemStats` writes K–N for all items in that section

| Cubit | Mutations that refresh stats |
|---|---|
| `CategoryCubit` | `issue`, `registerDamage`, `addQty` |
| `IssuesCubit` | `returnIssue` (uses `record.categoryTab`) |
| `DamageLogCubit` | `repairDamage` (uses `record.categoryTab`) |
| `ItemDetailCubit` | `repairDamage` |

## Partial return / partial repair flow

**Partial return** (`IssueRepository.partialReturn`): reduce existing open row's `Quantity` by returnedQty (stays `Open`) + append new `Returned` row for returnedQty. Both writes in parallel.

**Partial repair** (`DamageRepository.partialRepair`): reduce existing `Damaged` row's `Quantity` by repairedQty (stays `Damaged`) + append new `Repaired` row for repairedQty. Both writes in parallel.

## Delete section flow

`SheetsRepository.deleteSection`: 2 round trips.
1. Parallel: `spreadsheets.get` (sheetIds) + `batchGet` (read both log tabs)
2. Single `batchUpdate`: delete matching rows from `_IssueLog` (filtered by `CategoryTab`) + `_DamageLog` + delete section tab

## Sheet initialization

On `RoomsCubit.createRoom`, `SheetsRepository.initializeSpreadsheet` runs immediately after the Drive file is created:
1. Bolds header / un-bolds data rows / freezes row 1 on all existing section tabs
2. Creates `_IssueLog` with headers + bold header + Status dropdown + Open/Returned conditional colours
3. Creates `_DamageLog` with headers + bold header

**Bold inheritance fix**: after every `appendRow`, `unboldDataRows` is called. Google Sheets `values.append` copies the format of the row above, so appended rows inherit the bold header — this resets them to non-bold.

`ensureHeaders` is called before every `appendRow` in `addItem` to guarantee row 1 is a header row (handles renamed Sheet1 tabs that were never initialized).

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
| `/room/:id` | `RoomScreen` — section list; "Logs" popup → Issue Log or Damage Log |
| `/room/:id/category/:tab` | `CategoryScreen` — items with filterable Total/Issued/Damaged/Available summary bar |
| `/room/:id/category/:tab/item` | `ItemDetailScreen` — detail + issue history + damage history with Repair (`extra: InventoryItem`, `tab` in path) |
| `/room/:id/log` | `IssuesScreen` — issue/return log with partial return support |
| `/room/:id/damage-log` | `DamageLogScreen` — damage log with partial repair support |

## CategoryScreen filter bar

Tapping a stat in the summary bar filters the item list:
- **Total** → all items (resets filter)
- **Issued** → items where `issued > 0`
- **Damaged** → items where `damaged > 0`
- **Available** → items where `available > 0`

Active filter shown with tinted background + coloured underline. Tapping the active stat again resets to all.

## Item card actions (⋮ menu)

| Action | Notes |
|---|---|
| Issue | Disabled (greyed) when `available == 0` |
| Add qty | Dialog to add stock; updates Quantity in sheet + refreshes K–N |
| Mark damaged | Opens `DamageItemSheet`; appends to `_DamageLog` |
| Delete | Confirmation dialog; deletes the item row |

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
- **Stat columns (K–N) are write-only** — app always derives counts from raw log rows, never reads K–N back.
- **Category names store emoji prefix** — e.g. `"🎵 Music"`. Use `_leadingEmoji()` / `_displayName()` in `rooms_screen.dart` to split.
- **Colors**: Issued = `scheme.tertiary`, Damaged = `scheme.error`, Available = `scheme.primary`.
- **Formatting failures are silently swallowed** — sheet formatting is cosmetic and must never break app flow.
- **Status values are capitalised** — `"Open"`, `"Returned"`, `"Damaged"`, `"Repaired"`. Parsing is case-insensitive for backward compatibility.
- **Bold inheritance**: always call `unboldDataRows` after `appendRow` — Sheets copies the header's bold to the appended row.
