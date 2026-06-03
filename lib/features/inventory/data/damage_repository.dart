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

  /// Total damaged units per itemId for a given category tab.
  Future<Map<String, int>> damagedByItem(
      String spreadsheetId, String categoryTab) async {
    final log = await readLog(spreadsheetId);
    final counts = <String, int>{};
    for (final r in log) {
      if (r.categoryTab == categoryTab) {
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
    );
    await _sheets.appendRow(
      spreadsheetId,
      SheetSchema.damageLogTab,
      record.toRow(),
      SheetSchema.damageLogHeaders.length,
    );
    // Appended rows inherit the bold header — reset data rows to normal.
    await _sheets.unboldDataRows(spreadsheetId, SheetSchema.damageLogTab);
    return record;
  }
}
