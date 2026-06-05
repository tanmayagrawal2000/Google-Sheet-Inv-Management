import 'package:googleapis/sheets/v4.dart' as sheets;

import '../../../core/config/sheet_schema.dart';
import '../../../core/network/google_apis.dart';
import '../../../core/utils/a1.dart';

/// Low-level Google Sheets operations shared by the inventory and issue
/// repositories: listing tabs, creating tabs, and batched value read/write.
class SheetsRepository {
  SheetsRepository(this._apis);

  final GoogleApis _apis;

  static const _userEntered = 'USER_ENTERED';

  /// Visible category tab titles in a workbook (excludes the hidden issue log).
  Future<List<String>> listCategoryTabs(String spreadsheetId) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(title,hidden)',
    );
    return (ss.sheets ?? [])
        .map((s) => s.properties?.title ?? '')
        .where((t) =>
            t.isNotEmpty &&
            t != SheetSchema.issueLogTab &&
            t != SheetSchema.damageLogTab)
        .toList();
  }

  Future<Set<String>> _allTabTitles(String spreadsheetId) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties.title',
    );
    return (ss.sheets ?? [])
        .map((s) => s.properties?.title ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Creates a category tab, writes its header row, formula headers,
  /// summary block, and applies formatting.
  Future<void> createCategory(String spreadsheetId, String title) async {
    final name = title.trim();
    final sheetId = await _addSheet(spreadsheetId, name, hidden: false);
    await writeRange(
      spreadsheetId,
      A1.headerRow(name, SheetSchema.itemHeaders.length),
      [SheetSchema.itemHeaders],
    );
    final fromCol = A1.columnLetter(SheetSchema.formulaColTotal);
    final toCol = A1.columnLetter(SheetSchema.formulaColAvailable);
    await writeRange(
      spreadsheetId,
      '${_qt(name)}!${fromCol}1:${toCol}1',
      [SheetSchema.formulaHeaders],
    );
    await _writeSummaryBlock(spreadsheetId, name, sheetId);
    try {
      await _applyHeaderFormat(spreadsheetId, sheetId);
    } catch (_) {}
  }

  /// Sets up the entire spreadsheet structure on first creation: bold headers
  /// on all existing section tabs, then both fully-formatted log tabs.
  Future<void> initializeSpreadsheet(String spreadsheetId) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    for (final tab in ss.sheets ?? []) {
      final title = tab.properties?.title ?? '';
      final id = tab.properties?.sheetId;
      if (id == null) continue;
      if (title == SheetSchema.issueLogTab || title == SheetSchema.damageLogTab) {
        continue;
      }
      await _applyHeaderFormat(spreadsheetId, id);
      await _writeSummaryBlock(spreadsheetId, title, id);
    }
    await ensureIssueLog(spreadsheetId);
    await ensureDamageLog(spreadsheetId);
  }

  /// Ensures the `_IssueLog` tab exists with headers and conditional colours.
  /// The Status dropdown is applied per-row when each issue is appended.
  Future<void> ensureIssueLog(String spreadsheetId) async {
    final titles = await _allTabTitles(spreadsheetId);
    if (titles.contains(SheetSchema.issueLogTab)) return;
    await _addSheet(spreadsheetId, SheetSchema.issueLogTab, hidden: false);
    await writeRange(
      spreadsheetId,
      A1.headerRow(SheetSchema.issueLogTab, SheetSchema.issueLogHeaders.length),
      [SheetSchema.issueLogHeaders],
    );
    await formatIssueLog(spreadsheetId);
  }

  /// Ensures the `_DamageLog` tab exists with headers, bold header row,
  /// and Status conditional colours.
  Future<void> ensureDamageLog(String spreadsheetId) async {
    final titles = await _allTabTitles(spreadsheetId);
    if (titles.contains(SheetSchema.damageLogTab)) return;
    await _addSheet(spreadsheetId, SheetSchema.damageLogTab, hidden: false);
    await writeRange(
      spreadsheetId,
      A1.headerRow(SheetSchema.damageLogTab, SheetSchema.damageLogHeaders.length),
      [SheetSchema.damageLogHeaders],
    );
    await formatDamageLog(spreadsheetId);
  }

  /// Ensures [tab] has the item header row in row 1.
  /// Only writes headers when every cell in row 1 is empty — never overwrites
  /// existing data, even when optional fields like SNo are blank.
  Future<void> ensureHeaders(String spreadsheetId, String tab) async {
    final rows = await readRange(
      spreadsheetId,
      A1.headerRow(tab, SheetSchema.itemHeaders.length),
    );
    final row1 = rows.isNotEmpty ? rows.first : const <Object?>[];
    final hasContent = row1.any((c) => (c?.toString() ?? '').isNotEmpty);
    if (hasContent) return; // row 1 already has data
    await writeRange(
      spreadsheetId,
      A1.headerRow(tab, SheetSchema.itemHeaders.length),
      [SheetSchema.itemHeaders],
    );
    final fromCol = A1.columnLetter(SheetSchema.formulaColTotal);
    final toCol = A1.columnLetter(SheetSchema.formulaColAvailable);
    await writeRange(
      spreadsheetId,
      '${_qt(tab)}!${fromCol}1:${toCol}1',
      [SheetSchema.formulaHeaders],
    );
  }

  /// Renames a category tab from [oldTitle] to [newTitle].
  Future<void> renameCategory(String spreadsheetId, String oldTitle, String newTitle) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    final match = (ss.sheets ?? [])
        .where((s) => s.properties?.title == oldTitle)
        .firstOrNull;
    if (match == null) throw StateError('Sheet "$oldTitle" not found.');
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
            properties: sheets.SheetProperties(
              sheetId: match.properties!.sheetId,
              title: newTitle.trim(),
            ),
            fields: 'title',
          ),
        ),
      ]),
      spreadsheetId,
    );
  }

  /// Creates a new sheet tab and returns its numeric sheetId.
  Future<int> _addSheet(String spreadsheetId, String title, {required bool hidden}) async {
    final api = await _apis.sheetsApi();
    final resp = await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          addSheet: sheets.AddSheetRequest(
            properties: sheets.SheetProperties(title: title, hidden: hidden),
          ),
        ),
      ]),
      spreadsheetId,
    );
    return resp.replies!.first.addSheet!.properties!.sheetId!;
  }

  // ── Sheet formatting helpers ───────────────────────────────────────────────

  static sheets.Color _rgb(double r, double g, double b) =>
      sheets.Color(red: r, green: g, blue: b);

  /// Writes a 5-row summary block (Total / Issued / Damaged / Available) using
  /// whole-column SUM formulas, then encloses it in a black border.
  /// Positioned dynamically at [SheetSchema.summaryLabelCol] so adding new
  /// data or formula columns never displaces it.
  Future<void> _writeSummaryBlock(
      String spreadsheetId, String tab, int sheetId) async {
    final lCol = A1.columnLetter(SheetSchema.summaryLabelCol);
    final vCol = A1.columnLetter(SheetSchema.summaryValueCol);

    final tc = A1.columnLetter(SheetSchema.formulaColTotal);
    final ic = A1.columnLetter(SheetSchema.formulaColIssued);
    final dc = A1.columnLetter(SheetSchema.formulaColDamaged);
    final ac = A1.columnLetter(SheetSchema.formulaColAvailable);

    // Write values + formulas.
    await writeRange(
      spreadsheetId,
      '${_qt(tab)}!${lCol}1:${vCol}5',
      [
        ['Summary', ''],
        ['Total',     '=SUM($tc:$tc)'],
        ['Issued',    '=SUM($ic:$ic)'],
        ['Damaged',   '=SUM($dc:$dc)'],
        ['Available', '=SUM($ac:$ac)'],
      ],
    );

    // Apply black outer border + thin inner borders.
    final api = await _apis.sheetsApi();
    final black = sheets.Border(
        style: 'SOLID_MEDIUM', color: sheets.Color(red: 0, green: 0, blue: 0));
    final thin = sheets.Border(
        style: 'SOLID',
        color: sheets.Color(red: 0.6, green: 0.6, blue: 0.6));
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          updateBorders: sheets.UpdateBordersRequest(
            range: sheets.GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: 5,
              startColumnIndex: SheetSchema.summaryLabelCol,
              endColumnIndex: SheetSchema.summaryValueCol + 1,
            ),
            top: black,
            bottom: black,
            left: black,
            right: black,
            innerHorizontal: thin,
            innerVertical: thin,
          ),
        ),
      ]),
      spreadsheetId,
    );
  }

  /// Executes [_headerFormatRequests] for a known [sheetId].
  Future<void> _applyHeaderFormat(String spreadsheetId, int sheetId) async {
    final api = await _apis.sheetsApi();
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: _headerFormatRequests(sheetId)),
      spreadsheetId,
    );
  }

  /// Builds idempotent header-format requests: bold row 1, un-bold rows 2+
  /// (so appended rows never inherit the header bold), and freeze row 1.
  List<sheets.Request> _headerFormatRequests(int sheetId) => [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(sheetId: sheetId, startRowIndex: 0, endRowIndex: 1),
            cell: sheets.CellData(
              userEnteredFormat:
                  sheets.CellFormat(textFormat: sheets.TextFormat(bold: true)),
            ),
            fields: 'userEnteredFormat.textFormat.bold',
          ),
        ),
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(sheetId: sheetId, startRowIndex: 1),
            cell: sheets.CellData(
              userEnteredFormat:
                  sheets.CellFormat(textFormat: sheets.TextFormat(bold: false)),
            ),
            fields: 'userEnteredFormat.textFormat.bold',
          ),
        ),
        sheets.Request(
          updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
            properties: sheets.SheetProperties(
              sheetId: sheetId,
              gridProperties: sheets.GridProperties(frozenRowCount: 1),
            ),
            fields: 'gridProperties.frozenRowCount',
          ),
        ),
      ];

  /// Open/Returned dropdown on a single Status cell at [rowIndex] (1-based).
  /// Applied per-row after each append so empty rows never show the arrow.
  sheets.Request _statusDropdownRequest(int sheetId, int rowIndex) =>
      sheets.Request(
        setDataValidation: sheets.SetDataValidationRequest(
          range: sheets.GridRange(
            sheetId: sheetId,
            startRowIndex: rowIndex - 1,
            endRowIndex: rowIndex,
            startColumnIndex: SheetSchema.logColStatus,
            endColumnIndex: SheetSchema.logColStatus + 1,
          ),
          rule: sheets.DataValidationRule(
            condition: sheets.BooleanCondition(
              type: 'ONE_OF_LIST',
              values: [
                sheets.ConditionValue(userEnteredValue: SheetSchema.statusOpen),
                sheets.ConditionValue(userEnteredValue: SheetSchema.statusReturned),
              ],
            ),
            showCustomUi: true,
            strict: false,
          ),
        ),
      );

  /// Applies the Status dropdown to a specific [rowIndex] (1-based) in
  /// [tab]. Call this right after appending an issue row.
  Future<void> applyStatusDropdownToRow(
      String spreadsheetId, String tab, int rowIndex) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    final match = (ss.sheets ?? [])
        .where((s) => s.properties?.title == tab)
        .firstOrNull;
    if (match == null) return;
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
          requests: [_statusDropdownRequest(match.properties!.sheetId!, rowIndex)]),
      spreadsheetId,
    );
  }

  /// Two conditional-format rules on the Status column: Open → yellow,
  /// Returned → green. [existingCount] rules are deleted first so re-running
  /// never stacks duplicates.
  List<sheets.Request> _issueConditionalRequests(int sheetId, int existingCount) {
    final statusRange = sheets.GridRange(
      sheetId: sheetId,
      startRowIndex: 1,
      startColumnIndex: SheetSchema.logColStatus,
      endColumnIndex: SheetSchema.logColStatus + 1,
    );
    sheets.Request addRule(String value, sheets.Color color, int index) =>
        sheets.Request(
          addConditionalFormatRule: sheets.AddConditionalFormatRuleRequest(
            index: index,
            rule: sheets.ConditionalFormatRule(
              ranges: [statusRange],
              booleanRule: sheets.BooleanRule(
                condition: sheets.BooleanCondition(
                  type: 'TEXT_EQ',
                  values: [sheets.ConditionValue(userEnteredValue: value)],
                ),
                format: sheets.CellFormat(backgroundColor: color),
              ),
            ),
          ),
        );
    return [
      // Delete existing rules high→low so indices stay valid.
      for (var i = existingCount - 1; i >= 0; i--)
        sheets.Request(
          deleteConditionalFormatRule:
              sheets.DeleteConditionalFormatRuleRequest(sheetId: sheetId, index: i),
        ),
      addRule(SheetSchema.statusOpen, _rgb(1.0, 0.95, 0.40), 0),
      addRule(SheetSchema.statusReturned, _rgb(0.72, 0.88, 0.80), 1),
    ];
  }

  /// Fully (re)formats `_IssueLog` in one get + one batchUpdate: header bold,
  /// data non-bold, freeze, Status dropdown, and Open/Returned colour rules.
  /// Idempotent — existing conditional rules are deleted before re-adding.
  Future<void> formatIssueLog(String spreadsheetId) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(sheetId,title),conditionalFormats)',
    );
    final sheet = (ss.sheets ?? [])
        .where((s) => s.properties?.title == SheetSchema.issueLogTab)
        .firstOrNull;
    if (sheet == null) return;
    final sheetId = sheet.properties!.sheetId!;
    final existingCount = sheet.conditionalFormats?.length ?? 0;

    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        ..._headerFormatRequests(sheetId),
        ..._issueConditionalRequests(sheetId, existingCount),
      ]),
      spreadsheetId,
    );
  }

  /// Fully (re)formats `_DamageLog`: header bold + Status conditional colours.
  /// Damaged → light red, Repaired → light green.
  Future<void> formatDamageLog(String spreadsheetId) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(sheetId,title),conditionalFormats)',
    );
    final sheet = (ss.sheets ?? [])
        .where((s) => s.properties?.title == SheetSchema.damageLogTab)
        .firstOrNull;
    if (sheet == null) return;
    final sheetId = sheet.properties!.sheetId!;
    final existingCount = sheet.conditionalFormats?.length ?? 0;

    final statusRange = sheets.GridRange(
      sheetId: sheetId,
      startRowIndex: 1,
      startColumnIndex: SheetSchema.damageLogColStatus,
      endColumnIndex: SheetSchema.damageLogColStatus + 1,
    );

    sheets.Request rule(String value, sheets.Color color, int index) =>
        sheets.Request(
          addConditionalFormatRule: sheets.AddConditionalFormatRuleRequest(
            index: index,
            rule: sheets.ConditionalFormatRule(
              ranges: [statusRange],
              booleanRule: sheets.BooleanRule(
                condition: sheets.BooleanCondition(
                  type: 'TEXT_EQ',
                  values: [sheets.ConditionValue(userEnteredValue: value)],
                ),
                format: sheets.CellFormat(backgroundColor: color),
              ),
            ),
          ),
        );

    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        ..._headerFormatRequests(sheetId),
        // Delete existing rules high→low then re-add (idempotent).
        for (var i = existingCount - 1; i >= 0; i--)
          sheets.Request(
            deleteConditionalFormatRule:
                sheets.DeleteConditionalFormatRuleRequest(
                    sheetId: sheetId, index: i),
          ),
        rule(SheetSchema.damageStatusDamaged, _rgb(0.95, 0.80, 0.80), 0),
        rule(SheetSchema.damageStatusRepaired, _rgb(0.72, 0.88, 0.80), 1),
      ]),
      spreadsheetId,
    );
  }

  /// Dropdown (Damaged / Repaired) on a single Status cell at [rowIndex].
  Future<void> applyDamageStatusDropdownToRow(
      String spreadsheetId, int rowIndex) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    final match = (ss.sheets ?? [])
        .where((s) => s.properties?.title == SheetSchema.damageLogTab)
        .firstOrNull;
    if (match == null) return;
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          setDataValidation: sheets.SetDataValidationRequest(
            range: sheets.GridRange(
              sheetId: match.properties!.sheetId!,
              startRowIndex: rowIndex - 1,
              endRowIndex: rowIndex,
              startColumnIndex: SheetSchema.damageLogColStatus,
              endColumnIndex: SheetSchema.damageLogColStatus + 1,
            ),
            rule: sheets.DataValidationRule(
              condition: sheets.BooleanCondition(
                type: 'ONE_OF_LIST',
                values: [
                  sheets.ConditionValue(
                      userEnteredValue: SheetSchema.damageStatusDamaged),
                  sheets.ConditionValue(
                      userEnteredValue: SheetSchema.damageStatusRepaired),
                ],
              ),
              showCustomUi: true,
              strict: false,
            ),
          ),
        ),
      ]),
      spreadsheetId,
    );
  }

  /// Resets all data rows (row 2 onward) of [tab] to non-bold. Call this after
  /// appending rows: `values.append` copies the format of the row above the new
  /// row, so rows added below the bold header otherwise inherit bold.
  Future<void> unboldDataRows(String spreadsheetId, String tab) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    final match = (ss.sheets ?? [])
        .where((s) => s.properties?.title == tab)
        .firstOrNull;
    if (match == null) return;
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
                sheetId: match.properties!.sheetId!, startRowIndex: 1),
            cell: sheets.CellData(
              userEnteredFormat:
                  sheets.CellFormat(textFormat: sheets.TextFormat(bold: false)),
            ),
            fields: 'userEnteredFormat.textFormat.bold',
          ),
        ),
      ]),
      spreadsheetId,
    );
  }

  /// Reads a single A1 range as a 2D list of strings.
  Future<List<List<Object?>>> readRange(String spreadsheetId, String range) async {
    final api = await _apis.sheetsApi();
    final resp = await api.spreadsheets.values.get(spreadsheetId, range);
    return resp.values ?? const [];
  }

  /// Reads multiple ranges in a single request.
  Future<Map<String, List<List<Object?>>>> batchRead(
    String spreadsheetId,
    List<String> ranges,
  ) async {
    if (ranges.isEmpty) return {};
    final api = await _apis.sheetsApi();
    final resp = await api.spreadsheets.values.batchGet(spreadsheetId, ranges: ranges);
    final out = <String, List<List<Object?>>>{};
    for (final vr in resp.valueRanges ?? <sheets.ValueRange>[]) {
      out[vr.range ?? ''] = vr.values ?? const [];
    }
    return out;
  }

  /// Appends a single row to the bottom of [tab]'s data.
  /// Returns the 1-based row index of the appended row, or null if unknown.
  Future<int?> appendRow(String spreadsheetId, String tab, List<Object?> row, int columnCount) async {
    final api = await _apis.sheetsApi();
    final response = await api.spreadsheets.values.append(
      sheets.ValueRange(values: [row]),
      spreadsheetId,
      A1.wholeTab(tab, columnCount),
      valueInputOption: _userEntered,
      insertDataOption: 'OVERWRITE',
    );
    // Parse row number from updatedRange like "'Tab'!A5:G5".
    final updated = response.updates?.updatedRange;
    if (updated == null) return null;
    final cellPart = updated.contains('!') ? updated.split('!').last : updated;
    final match = RegExp(r'[A-Z]+(\d+)').firstMatch(cellPart);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Writes initial stat values for a newly added item (issued=0, damaged=0).
  Future<void> writeItemFormulas(
      String spreadsheetId, String tab, int rowIndex, int quantity) async {
    final totalCol = A1.columnLetter(SheetSchema.formulaColTotal);
    final availCol = A1.columnLetter(SheetSchema.formulaColAvailable);
    await writeRange(
      spreadsheetId,
      '${_qt(tab)}!$totalCol$rowIndex:$availCol$rowIndex',
      [[quantity, 0, 0, quantity]],
    );
  }

  /// Batch-writes the current Total/Issued/Damaged/Available values for every
  /// item in [items] that has a known rowIndex. Call this after any mutation
  /// (issue, return, damage) so the sheet reflects the app's in-memory counts
  /// without depending on cross-sheet SUMPRODUCT auto-recalculation — which
  /// the Sheets API does not trigger reliably.
  Future<void> batchWriteItemStats(
      String spreadsheetId, String tab, List<dynamic> items) async {
    final totalCol = A1.columnLetter(SheetSchema.formulaColTotal);
    final availCol = A1.columnLetter(SheetSchema.formulaColAvailable);

    final data = <sheets.ValueRange>[];
    for (final item in items) {
      final row = item.rowIndex as int?;
      if (row == null) continue;
      data.add(sheets.ValueRange(
        range: '${_qt(tab)}!$totalCol$row:$availCol$row',
        values: [
          [item.quantity as int, item.issued as int, item.damaged as int, item.available as int]
        ],
      ));
    }
    if (data.isEmpty) return;
    final api = await _apis.sheetsApi();
    await api.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        data: data,
        valueInputOption: _userEntered,
      ),
      spreadsheetId,
    );
  }

  /// Deletes [tab] and removes every record that references it from both log
  /// tabs. Uses 2 parallel reads + 1 batchUpdate (2 round trips total).
  Future<void> deleteSection(String spreadsheetId, String tab) async {
    final api = await _apis.sheetsApi();

    // ── Round trip 1: two parallel reads ──────────────────────────────────
    final results = await Future.wait<Object?>([
      // sheetIds for section tab + both log tabs.
      api.spreadsheets
          .get(spreadsheetId, $fields: 'sheets.properties(sheetId,title)'),
      // All rows from both logs in one call.
      api.spreadsheets.values.batchGet(
        spreadsheetId,
        ranges: [
          A1.wholeTab(
              SheetSchema.issueLogTab, SheetSchema.issueLogHeaders.length),
          A1.wholeTab(
              SheetSchema.damageLogTab, SheetSchema.damageLogHeaders.length),
        ],
      ),
    ]);

    final ss = results[0] as sheets.Spreadsheet;
    final batchResult = results[1] as sheets.BatchGetValuesResponse;

    // Build a title → sheetId map.
    final sheetMap = <String, int>{};
    for (final s in ss.sheets ?? []) {
      final title = s.properties?.title;
      final id = s.properties?.sheetId;
      if (title != null && id != null) sheetMap[title] = id;
    }

    final sectionSheetId = sheetMap[tab];
    if (sectionSheetId == null) return; // already gone

    final issueSheetId = sheetMap[SheetSchema.issueLogTab];
    final damageSheetId = sheetMap[SheetSchema.damageLogTab];

    // Find 1-based row indices where CategoryTab matches [tab].
    List<int> matchingRows(List<List<Object?>> rows, int categoryTabCol) {
      final result = <int>[];
      for (var i = SheetSchema.firstDataRow - 1; i < rows.length; i++) {
        final row = rows[i];
        if (categoryTabCol < row.length &&
            row[categoryTabCol]?.toString() == tab) {
          result.add(i + 1);
        }
      }
      return result;
    }

    final valueRanges = batchResult.valueRanges ?? [];
    final issueRows = issueSheetId != null && valueRanges.isNotEmpty
        ? matchingRows(
            valueRanges[0].values ?? [], SheetSchema.logColCategoryTab)
        : <int>[];
    final damageRows = damageSheetId != null && valueRanges.length > 1
        ? matchingRows(
            valueRanges[1].values ?? [], SheetSchema.damageLogColCategoryTab)
        : <int>[];

    // ── Round trip 2: one batchUpdate does everything ──────────────────────
    final requests = <sheets.Request>[];

    sheets.Request deleteRow(int sheetId, int rowIndex) => sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: rowIndex - 1, // 0-based inclusive
              endIndex: rowIndex,       // 0-based exclusive
            ),
          ),
        );

    // Delete high → low so earlier deletions don't shift later indices.
    for (final row in issueRows.reversed) {
      requests.add(deleteRow(issueSheetId!, row));
    }
    for (final row in damageRows.reversed) {
      requests.add(deleteRow(damageSheetId!, row));
    }

    // Delete the section tab itself (last, after log cleanup).
    requests.add(
        sheets.Request(deleteSheet: sheets.DeleteSheetRequest(sheetId: sectionSheetId)));

    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: requests),
      spreadsheetId,
    );
  }

  /// Overwrites the Quantity cell for [rowIndex] with [newQty].
  Future<void> updateItemQuantity(
      String spreadsheetId, String tab, int rowIndex, int newQty) async {
    final col = A1.columnLetter(SheetSchema.itemColQuantity);
    await writeRange(
        spreadsheetId, '${_qt(tab)}!$col$rowIndex:$col$rowIndex', [[newQty]]);
  }

  static String _qt(String tab) => "'${tab.replaceAll("'", "''")}'";

  /// Deletes a single row (1-based [rowIndex]) from [tab].
  Future<void> deleteRow(String spreadsheetId, String tab, int rowIndex) async {
    final api = await _apis.sheetsApi();
    final ss = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets.properties(sheetId,title)',
    );
    final match = (ss.sheets ?? [])
        .where((s) => s.properties?.title == tab)
        .firstOrNull;
    if (match == null) throw StateError('Sheet "$tab" not found.');
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: match.properties!.sheetId,
              dimension: 'ROWS',
              startIndex: rowIndex - 1, // API is 0-based
              endIndex: rowIndex,
            ),
          ),
        ),
      ]),
      spreadsheetId,
    );
  }

  /// Overwrites a specific A1 range.
  Future<void> writeRange(String spreadsheetId, String range, List<List<Object?>> values) async {
    final api = await _apis.sheetsApi();
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: values),
      spreadsheetId,
      range,
      valueInputOption: _userEntered,
    );
  }
}
