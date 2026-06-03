import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../core/config/sheet_schema.dart';

/// One row in the `_IssueLog` append-only ledger.
class IssueRecord extends Equatable {
  const IssueRecord({
    required this.logId,
    required this.categoryTab,
    required this.itemId,
    required this.itemDetail,
    required this.quantity,
    required this.borrower,
    required this.dateIssued,
    this.expectedReturn,
    this.dateReturned,
    required this.status,
    this.rowIndex,
  });

  final String logId;
  final String categoryTab;
  final String itemId;
  final String itemDetail;
  final int quantity;
  final String borrower;
  final DateTime dateIssued;
  final DateTime? expectedReturn;
  final DateTime? dateReturned;

  /// [SheetSchema.statusOpen] or [SheetSchema.statusReturned].
  final String status;

  /// 1-based row number in the `_IssueLog` tab, when known.
  final int? rowIndex;

  bool get isOpen =>
      status.toLowerCase() != SheetSchema.statusReturned.toLowerCase();

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// Maps stored status text (any casing, blank) to a canonical value.
  static String _normalizeStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == SheetSchema.statusReturned.toLowerCase()) {
      return SheetSchema.statusReturned;
    }
    return SheetSchema.statusOpen;
  }

  static String _date(DateTime? d) => d == null ? '' : _fmt.format(d);
  static DateTime? _parse(String s) =>
      s.trim().isEmpty ? null : DateTime.tryParse(s.trim());

  IssueRecord copyWith({
    DateTime? dateReturned,
    String? status,
    int? rowIndex,
  }) =>
      IssueRecord(
        logId: logId,
        categoryTab: categoryTab,
        itemId: itemId,
        itemDetail: itemDetail,
        quantity: quantity,
        borrower: borrower,
        dateIssued: dateIssued,
        expectedReturn: expectedReturn,
        dateReturned: dateReturned ?? this.dateReturned,
        status: status ?? this.status,
        rowIndex: rowIndex ?? this.rowIndex,
      );

  /// Serializes to a ledger row in [SheetSchema.issueLogHeaders] order.
  List<Object?> toRow() {
    final row = List<Object?>.filled(SheetSchema.issueLogHeaders.length, '');
    row[SheetSchema.logColLogId] = logId;
    row[SheetSchema.logColCategoryTab] = categoryTab;
    row[SheetSchema.logColItemId] = itemId;
    row[SheetSchema.logColItemDetail] = itemDetail;
    row[SheetSchema.logColQuantity] = quantity;
    row[SheetSchema.logColBorrower] = borrower;
    row[SheetSchema.logColDateIssued] = _date(dateIssued);
    row[SheetSchema.logColExpectedReturn] = _date(expectedReturn);
    row[SheetSchema.logColDateReturned] = _date(dateReturned);
    row[SheetSchema.logColStatus] = status;
    return row;
  }

  /// Parses a ledger row. [rowIndex] is the 1-based row number.
  static IssueRecord? fromRow(List<Object?> row, {int? rowIndex}) {
    String cell(int i) => i < row.length ? (row[i]?.toString() ?? '') : '';
    final logId = cell(SheetSchema.logColLogId);
    if (logId.isEmpty) return null;
    return IssueRecord(
      logId: logId,
      categoryTab: cell(SheetSchema.logColCategoryTab),
      itemId: cell(SheetSchema.logColItemId),
      itemDetail: cell(SheetSchema.logColItemDetail),
      quantity: int.tryParse(cell(SheetSchema.logColQuantity)) ?? 0,
      borrower: cell(SheetSchema.logColBorrower),
      dateIssued: _parse(cell(SheetSchema.logColDateIssued)) ?? DateTime.now(),
      expectedReturn: _parse(cell(SheetSchema.logColExpectedReturn)),
      dateReturned: _parse(cell(SheetSchema.logColDateReturned)),
      status: _normalizeStatus(cell(SheetSchema.logColStatus)),
      rowIndex: rowIndex,
    );
  }

  @override
  List<Object?> get props => [
        logId,
        categoryTab,
        itemId,
        itemDetail,
        quantity,
        borrower,
        dateIssued,
        expectedReturn,
        dateReturned,
        status,
        rowIndex,
      ];
}
