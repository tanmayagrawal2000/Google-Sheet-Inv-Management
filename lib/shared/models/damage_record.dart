import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../core/config/sheet_schema.dart';

class DamageRecord extends Equatable {
  const DamageRecord({
    required this.logId,
    required this.categoryTab,
    required this.itemId,
    required this.itemDetail,
    required this.quantity,
    required this.damagedDate,
    this.details = '',
    this.rowIndex,
  });

  final String logId;
  final String categoryTab;
  final String itemId;
  final String itemDetail;
  final int quantity;
  final DateTime damagedDate;
  final String details;
  final int? rowIndex;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static String _date(DateTime d) => _fmt.format(d);
  static DateTime? _parse(String s) =>
      s.trim().isEmpty ? null : DateTime.tryParse(s.trim());

  List<Object?> toRow() {
    final row = List<Object?>.filled(SheetSchema.damageLogHeaders.length, '');
    row[SheetSchema.damageLogColLogId] = logId;
    row[SheetSchema.damageLogColCategoryTab] = categoryTab;
    row[SheetSchema.damageLogColItemId] = itemId;
    row[SheetSchema.damageLogColItemDetail] = itemDetail;
    row[SheetSchema.damageLogColQuantity] = quantity;
    row[SheetSchema.damageLogColDamagedDate] = _date(damagedDate);
    row[SheetSchema.damageLogColDetails] = details;
    return row;
  }

  static DamageRecord? fromRow(List<Object?> row, {int? rowIndex}) {
    String cell(int i) => i < row.length ? (row[i]?.toString() ?? '') : '';
    final logId = cell(SheetSchema.damageLogColLogId);
    if (logId.isEmpty) return null;
    final date = _parse(cell(SheetSchema.damageLogColDamagedDate)) ?? DateTime.now();
    return DamageRecord(
      logId: logId,
      categoryTab: cell(SheetSchema.damageLogColCategoryTab),
      itemId: cell(SheetSchema.damageLogColItemId),
      itemDetail: cell(SheetSchema.damageLogColItemDetail),
      quantity: int.tryParse(cell(SheetSchema.damageLogColQuantity)) ?? 0,
      damagedDate: date,
      details: cell(SheetSchema.damageLogColDetails),
      rowIndex: rowIndex,
    );
  }

  @override
  List<Object?> get props =>
      [logId, categoryTab, itemId, itemDetail, quantity, damagedDate, details, rowIndex];
}
