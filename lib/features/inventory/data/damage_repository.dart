import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/sheet_schema.dart';
import '../../../core/utils/a1.dart';
import '../../../shared/models/damage_record.dart';
import 'sheets_repository.dart';

class DamageRepository {
  DamageRepository(this._sheets);

  final SheetsRepository _sheets;
  final _uuid = const Uuid();

  Future<List<DamageRecord>> readLog(String spreadsheetId) async {
    await _sheets.ensureDamageLog(spreadsheetId);
    final range = A1.wholeTab(
        SheetSchema.damageLogTab, SheetSchema.damageLogHeaders.length);
    final rows = await _sheets.readRange(spreadsheetId, range);
    final out = <DamageRecord>[];
    for (var i = SheetSchema.firstDataRow - 1; i < rows.length; i++) {
      final record = DamageRecord.fromRow(rows[i], rowIndex: i + 1);
      if (record != null) out.add(record);
    }
    return out;
  }

  /// Total **unrepaired** damaged units per itemId for a given category tab.
  Future<Map<String, int>> damagedByItem(
      String spreadsheetId, String categoryTab) async {
    final log = await readLog(spreadsheetId);
    final counts = <String, int>{};
    for (final r in log) {
      if (r.isDamaged && r.categoryTab == categoryTab) {
        counts[r.itemId] = (counts[r.itemId] ?? 0) + r.quantity;
      }
    }
    return counts;
  }

  Future<DamageRecord> recordDamage(
    String spreadsheetId, {
    required String categoryTab,
    required String itemId,
    required String itemDetail,
    required int quantity,
    required DateTime damagedDate,
    String details = '',
  }) async {
    await _sheets.ensureDamageLog(spreadsheetId);
    final record = DamageRecord(
      logId: _uuid.v4(),
      categoryTab: categoryTab,
      itemId: itemId,
      itemDetail: itemDetail,
      quantity: quantity,
      damagedDate: damagedDate,
      details: details.trim(),
      status: SheetSchema.damageStatusDamaged,
    );
    final rowIndex = await _sheets.appendRow(
      spreadsheetId,
      SheetSchema.damageLogTab,
      record.toRow(),
      SheetSchema.damageLogHeaders.length,
    );
    await Future.wait([
      _sheets.unboldDataRows(spreadsheetId, SheetSchema.damageLogTab),
      if (rowIndex != null)
        _sheets.applyDamageStatusDropdownToRow(spreadsheetId, rowIndex),
      _sheets.formatDamageLog(spreadsheetId),
    ]);
    return record;
  }

  /// Marks an entire damage record as repaired, writing RepairDate + Status.
  Future<void> markRepaired(String spreadsheetId, DamageRecord record) async {
    if (record.rowIndex == null) {
      throw StateError('Cannot repair without a known row index.');
    }
    // RepairDate (index 7, col H) comes before Status (index 8, col I).
    final repairCol = A1.columnLetter(SheetSchema.damageLogColRepairDate);
    final statusCol = A1.columnLetter(SheetSchema.damageLogColStatus);
    final range =
        "'${SheetSchema.damageLogTab}'!$repairCol${record.rowIndex}:$statusCol${record.rowIndex}";
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _sheets.writeRange(
        spreadsheetId, range, [[dateStr, SheetSchema.damageStatusRepaired]]);
  }

  /// Partially repairs [repairedQty] units of [record].
  /// Reduces the existing damaged row's qty, appends a new Repaired row.
  Future<void> partialRepair(
      String spreadsheetId, DamageRecord record, int repairedQty) async {
    if (record.rowIndex == null) {
      throw StateError('Cannot partial-repair without a known row index.');
    }
    final remainingQty = record.quantity - repairedQty;
    final qtyCol = A1.columnLetter(SheetSchema.damageLogColQuantity);
    final qtyRange =
        "'${SheetSchema.damageLogTab}'!$qtyCol${record.rowIndex}:$qtyCol${record.rowIndex}";

    final repairedRecord = DamageRecord(
      logId: _uuid.v4(),
      categoryTab: record.categoryTab,
      itemId: record.itemId,
      itemDetail: record.itemDetail,
      quantity: repairedQty,
      damagedDate: record.damagedDate,
      details: record.details,
      status: SheetSchema.damageStatusRepaired,
      repairDate: DateTime.now(),
    );

    // Both writes in parallel.
    await Future.wait([
      _sheets.writeRange(spreadsheetId, qtyRange, [[remainingQty]]),
      _sheets.appendRow(
        spreadsheetId,
        SheetSchema.damageLogTab,
        repairedRecord.toRow(),
        SheetSchema.damageLogHeaders.length,
      ),
    ]);
    await _sheets.unboldDataRows(spreadsheetId, SheetSchema.damageLogTab);
  }
}
