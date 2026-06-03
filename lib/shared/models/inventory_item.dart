import 'package:equatable/equatable.dart';

import '../../core/config/sheet_schema.dart';

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.itemId,
    required this.sno,
    required this.detail,
    required this.firmName,
    required this.price,
    required this.quantity,
    required this.notes,
    this.imageUrl = '',
    this.billNo = '',
    this.billDate = '',
    this.issued = 0,
    this.damaged = 0,
    this.rowIndex,
  });

  final String itemId;
  final String sno;
  final String detail;
  final String firmName;
  final String price;
  final int quantity;
  final String notes;
  final String imageUrl;
  final String billNo;
  final String billDate;

  /// Derived from _IssueLog (open records).
  final int issued;

  /// Derived from _DamageLog.
  final int damaged;

  final int? rowIndex;

  int get available => (quantity - issued - damaged).clamp(0, quantity);

  String? get thumbnailUrl {
    if (imageUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final dIdx = segments.indexOf('d');
      if (dIdx < 0 || dIdx + 1 >= segments.length) return null;
      return 'https://drive.google.com/thumbnail?id=${segments[dIdx + 1]}&sz=w200';
    } catch (_) {
      return null;
    }
  }

  InventoryItem copyWith({
    String? imageUrl,
    int? issued,
    int? damaged,
    int? rowIndex,
  }) =>
      InventoryItem(
        itemId: itemId,
        sno: sno,
        detail: detail,
        firmName: firmName,
        price: price,
        quantity: quantity,
        notes: notes,
        imageUrl: imageUrl ?? this.imageUrl,
        billNo: billNo,
        billDate: billDate,
        issued: issued ?? this.issued,
        damaged: damaged ?? this.damaged,
        rowIndex: rowIndex ?? this.rowIndex,
      );

  List<Object?> toRow() {
    final row = List<Object?>.filled(SheetSchema.itemHeaders.length, '');
    row[SheetSchema.itemColSNo] = sno;
    row[SheetSchema.itemColDetail] = detail;
    row[SheetSchema.itemColFirmName] = firmName;
    row[SheetSchema.itemColPrice] = price;
    row[SheetSchema.itemColQuantity] = quantity;
    row[SheetSchema.itemColItemId] = itemId;
    row[SheetSchema.itemColNotes] = notes;
    row[SheetSchema.itemColImageUrl] = imageUrl;
    row[SheetSchema.itemColBillNo] = billNo;
    row[SheetSchema.itemColBillDate] = billDate;
    return row;
  }

  static InventoryItem fromRow(List<Object?> row, {int? rowIndex}) {
    String cell(int i) => i < row.length ? (row[i]?.toString() ?? '') : '';
    final qty = int.tryParse(cell(SheetSchema.itemColQuantity)) ?? 1;
    return InventoryItem(
      itemId: cell(SheetSchema.itemColItemId),
      sno: cell(SheetSchema.itemColSNo),
      detail: cell(SheetSchema.itemColDetail),
      firmName: cell(SheetSchema.itemColFirmName),
      price: cell(SheetSchema.itemColPrice),
      quantity: qty,
      notes: cell(SheetSchema.itemColNotes),
      imageUrl: cell(SheetSchema.itemColImageUrl),
      billNo: cell(SheetSchema.itemColBillNo),
      billDate: cell(SheetSchema.itemColBillDate),
      rowIndex: rowIndex,
    );
  }

  @override
  List<Object?> get props => [
        itemId, sno, detail, firmName, price, quantity,
        notes, imageUrl, billNo, billDate, issued, damaged, rowIndex,
      ];
}
