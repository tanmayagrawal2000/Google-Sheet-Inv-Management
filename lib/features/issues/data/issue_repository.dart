import 'package:uuid/uuid.dart';

import '../../../core/config/sheet_schema.dart';
import '../../../core/utils/a1.dart';
import '../../../shared/models/issue_record.dart';
import '../../inventory/data/sheets_repository.dart';

/// Manages the per-workbook `_IssueLog` append-only ledger and derives how many
/// units of each item are currently issued (open).
class IssueRepository {
  IssueRepository(this._sheets);

  final SheetsRepository _sheets;
  final _uuid = const Uuid();

  /// Reads the full ledger (newest rows last), skipping the header.
  Future<List<IssueRecord>> readLog(String spreadsheetId) async {
    await _sheets.ensureIssueLog(spreadsheetId);
    final range = A1.wholeTab(SheetSchema.issueLogTab, SheetSchema.issueLogHeaders.length);
    final rows = await _sheets.readRange(spreadsheetId, range);
    final out = <IssueRecord>[];
    for (var i = SheetSchema.firstDataRow - 1; i < rows.length; i++) {
      final record = IssueRecord.fromRow(rows[i], rowIndex: i + 1);
      if (record != null) out.add(record);
    }
    return out;
  }

  /// Sum of open issued quantities per itemId for a given category tab.
  Future<Map<String, int>> openIssuedByItem(String spreadsheetId, String categoryTab) async {
    final log = await readLog(spreadsheetId);
    final counts = <String, int>{};
    for (final r in log) {
      if (r.isOpen && r.categoryTab == categoryTab) {
        counts[r.itemId] = (counts[r.itemId] ?? 0) + r.quantity;
      }
    }
    return counts;
  }

  /// Appends a new open issue record.
  Future<IssueRecord> issue(
    String spreadsheetId, {
    required String categoryTab,
    required String itemId,
    required String itemDetail,
    required int quantity,
    required String borrower,
    DateTime? expectedReturn,
  }) async {
    await _sheets.ensureIssueLog(spreadsheetId);
    final record = IssueRecord(
      logId: _uuid.v4(),
      categoryTab: categoryTab,
      itemId: itemId,
      itemDetail: itemDetail,
      quantity: quantity,
      borrower: borrower.trim(),
      dateIssued: DateTime.now(),
      expectedReturn: expectedReturn,
      status: SheetSchema.statusOpen,
    );
    await _sheets.appendRow(
      spreadsheetId,
      SheetSchema.issueLogTab,
      record.toRow(),
      SheetSchema.issueLogHeaders.length,
    );
    // Re-apply full issue-log formatting (header bold, data non-bold, Status
    // dropdown, Open/Returned colours). Idempotent — runs only on write, and
    // self-heals the formatting on any log that has issue activity.
    await _sheets.formatIssueLog(spreadsheetId);
    return record;
  }

  /// Permanently removes a log row from the sheet.
  Future<void> deleteRecord(String spreadsheetId, IssueRecord record) async {
    if (record.rowIndex == null) {
      throw StateError('Cannot delete a record without a known row index.');
    }
    await _sheets.deleteRow(spreadsheetId, SheetSchema.issueLogTab, record.rowIndex!);
  }

  /// Marks an open issue as returned by updating its DateReturned + Status
  /// cells in place. Requires [record.rowIndex] from a fresh [readLog].
  Future<IssueRecord> markReturned(String spreadsheetId, IssueRecord record) async {
    final rowIndex = record.rowIndex;
    if (rowIndex == null) {
      throw StateError('Cannot return an issue without a known row index.');
    }
    final returned = record.copyWith(
      dateReturned: DateTime.now(),
      status: SheetSchema.statusReturned,
    );
    // Write only the DateReturned..Status cells (contiguous trailing columns).
    final fromCol = A1.columnLetter(SheetSchema.logColDateReturned);
    final toCol = A1.columnLetter(SheetSchema.logColStatus);
    final range = "'${SheetSchema.issueLogTab}'!$fromCol$rowIndex:$toCol$rowIndex";
    final fullRow = returned.toRow();
    await _sheets.writeRange(spreadsheetId, range, [
      fullRow.sublist(SheetSchema.logColDateReturned, SheetSchema.logColStatus + 1),
    ]);
    return returned;
  }
}
