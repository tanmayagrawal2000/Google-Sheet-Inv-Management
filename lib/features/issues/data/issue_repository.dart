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
    final rowIndex = await _sheets.appendRow(
      spreadsheetId,
      SheetSchema.issueLogTab,
      record.toRow(),
      SheetSchema.issueLogHeaders.length,
    );
    // Apply dropdown to this row's Status cell only.
    // Conditional colours and header bold are set once at log creation.
    if (rowIndex != null) {
      await _sheets.applyStatusDropdownToRow(
          spreadsheetId, SheetSchema.issueLogTab, rowIndex);
    }
    return record;
  }

  /// Permanently removes a log row from the sheet.
  Future<void> deleteRecord(String spreadsheetId, IssueRecord record) async {
    if (record.rowIndex == null) {
      throw StateError('Cannot delete a record without a known row index.');
    }
    await _sheets.deleteRow(spreadsheetId, SheetSchema.issueLogTab, record.rowIndex!);
  }

  /// Marks an open issue as fully returned.
  Future<IssueRecord> markReturned(String spreadsheetId, IssueRecord record) async {
    final rowIndex = record.rowIndex;
    if (rowIndex == null) {
      throw StateError('Cannot return an issue without a known row index.');
    }
    final returned = record.copyWith(
      dateReturned: DateTime.now(),
      status: SheetSchema.statusReturned,
    );
    final fromCol = A1.columnLetter(SheetSchema.logColDateReturned);
    final toCol = A1.columnLetter(SheetSchema.logColStatus);
    final range = "'${SheetSchema.issueLogTab}'!$fromCol$rowIndex:$toCol$rowIndex";
    final fullRow = returned.toRow();
    await _sheets.writeRange(spreadsheetId, range, [
      fullRow.sublist(SheetSchema.logColDateReturned, SheetSchema.logColStatus + 1),
    ]);
    return returned;
  }

  /// Handles a partial return of [returnedQty] units from [record].
  Future<void> partialReturn(
      String spreadsheetId, IssueRecord record, int returnedQty) async {
    if (record.rowIndex == null) {
      throw StateError('Cannot partial-return without a known row index.');
    }
    final remainingQty = record.quantity - returnedQty;
    final qtyCol = A1.columnLetter(SheetSchema.logColQuantity);
    final qtyRange =
        "'${SheetSchema.issueLogTab}'!$qtyCol${record.rowIndex}:$qtyCol${record.rowIndex}";

    final returnedRecord = IssueRecord(
      logId: _uuid.v4(),
      categoryTab: record.categoryTab,
      itemId: record.itemId,
      itemDetail: record.itemDetail,
      quantity: returnedQty,
      borrower: record.borrower,
      dateIssued: record.dateIssued,
      expectedReturn: record.expectedReturn,
      dateReturned: DateTime.now(),
      status: SheetSchema.statusReturned,
    );

    final rowIndexFuture = _sheets.appendRow(
      spreadsheetId,
      SheetSchema.issueLogTab,
      returnedRecord.toRow(),
      SheetSchema.issueLogHeaders.length,
    );
    await Future.wait([
      _sheets.writeRange(spreadsheetId, qtyRange, [[remainingQty]]),
      rowIndexFuture,
    ]);

    final newRowIndex = await rowIndexFuture;
    if (newRowIndex != null) {
      await _sheets.applyStatusDropdownToRow(
          spreadsheetId, SheetSchema.issueLogTab, newRowIndex);
    }
  }
}
