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
    this.status = SheetSchema.damageStatusDamaged,
    this.rowIndex,
  });

  final String logId;
  final String categoryTab;
  final String itemId;
  final String itemDetail;
  final int quantity;
  final DateTime damagedDate;
  final String details;
  final String status;
  final int? rowIndex;

  bool get isDamaged =>
      status.toLowerCase() != SheetSchema.damageStatusRepaired.toLowerCase();

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static String _date(DateTime d) => _fmt.format(d);
  static DateTime? _parse(String s) =>
      s.trim().isEmpty ? null : DateTime.tryParse(s.trim());

  static String _normalizeStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == SheetSchema.damageStatusRepaired.toLowerCase()) {
      return SheetSchema.damageStatusRepaired;
    }
    return SheetSchema.damageStatusDamaged;
  }

  DamageRecord copyWith({String? status}) => DamageRecord(
        logId: logId,
        categoryTab: categoryTab,
        itemId: itemId,
        itemDetail: itemDetail,
        quantity: quantity,
        damagedDate: damagedDate,
        details: details,
        status: status ?? this.status,
        rowIndex: rowIndex,
      );

  List<Object?> toRow() {
    final row = List<Object?>.filled(SheetSchema.damageLogHeaders.length, '');
    row[SheetSchema.damageLogColLogId] = logId;
    row[SheetSchema.damageLogColCategoryTab] = categoryTab;
    row[SheetSchema.damageLogColItemId] = itemId;
    row[SheetSchema.damageLogColItemDetail] = itemDetail;
    row[SheetSchema.damageLogColQuantity] = quantity;
    row[SheetSchema.damageLogColDamagedDate] = _date(damagedDate);
    row[SheetSchema.damageLogColDetails] = details;
    row[SheetSchema.damageLogColStatus] = status;
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
      status: _normalizeStatus(cell(SheetSchema.damageLogColStatus)),
      rowIndex: rowIndex,
    );
  }

  @override
  List<Object?> get props =>
      [logId, categoryTab, itemId, itemDetail, quantity, damagedDate, details, status, rowIndex];
}
