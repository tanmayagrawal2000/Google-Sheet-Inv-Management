import 'package:uuid/uuid.dart';

import '../../../core/config/sheet_schema.dart';
import '../../../core/utils/a1.dart';
import '../../../shared/models/damage_record.dart';
import '../../../shared/models/inventory_item.dart';
import '../../issues/data/issue_repository.dart';
import 'damage_repository.dart';
import 'sheets_repository.dart';

/// Aggregate of a category tab's items plus their derived issued counts.
class CategoryData {
  CategoryData({required this.tab, required this.items});

  final String tab;
  final List<InventoryItem> items;

  int get totalUnits => items.fold(0, (s, i) => s + i.quantity);
  int get issuedUnits => items.fold(0, (s, i) => s + i.issued);
  int get damagedUnits => items.fold(0, (s, i) => s + i.damaged);
  int get availableUnits => items.fold(0, (s, i) => s + i.available);
}

/// High-level operations on categories (tabs) and items (rows), with
/// Total/Issued/Available derived from the issue log.
class CatalogRepository {
  CatalogRepository(this._sheets, this._issues, this._damage);

  final SheetsRepository _sheets;
  final IssueRepository _issues;
  final DamageRepository _damage;
  final _uuid = const Uuid();

  Future<List<String>> listCategories(String spreadsheetId) =>
      _sheets.listCategoryTabs(spreadsheetId);

  Future<void> createCategory(String spreadsheetId, String title) =>
      _sheets.createCategory(spreadsheetId, title);

  Future<void> renameCategory(String spreadsheetId, String oldTitle, String newTitle) =>
      _sheets.renameCategory(spreadsheetId, oldTitle, newTitle);

  Future<void> deleteCategory(String spreadsheetId, String title) =>
      _sheets.deleteSection(spreadsheetId, title);

  Future<void> addQty(
      String spreadsheetId, String tab, InventoryItem item, int extra) async {
    if (item.rowIndex == null) throw StateError('Row index unknown.');
    final newQty = item.quantity + extra;
    await _sheets.updateItemQuantity(spreadsheetId, tab, item.rowIndex!, newQty);
  }

  /// Loads all items in [tab] with `issued`/`available` filled from the log.
  Future<CategoryData> loadCategory(String spreadsheetId, String tab) async {
    final range = A1.wholeTab(tab, SheetSchema.itemHeaders.length);
    final results = await Future.wait([
      _sheets.readRange(spreadsheetId, range),
      _issues.openIssuedByItem(spreadsheetId, tab),
      _damage.damagedByItem(spreadsheetId, tab),
    ]);
    final rows = results[0] as List<List<Object?>>;
    final issued = results[1] as Map<String, int>;
    final damaged = results[2] as Map<String, int>;

    // Skip row 1 only if it is our header row. If it contains item data
    // (e.g. the sheet never had headers written), start reading from row 1.
    final hasHeader = rows.isNotEmpty &&
        rows.first.isNotEmpty &&
        rows.first.first?.toString() == SheetSchema.itemHeaders.first;
    final startIndex = hasHeader ? SheetSchema.firstDataRow - 1 : 0;

    final items = <InventoryItem>[];
    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => (c?.toString() ?? '').trim().isEmpty)) continue;
      final item = InventoryItem.fromRow(row, rowIndex: i + 1);
      if (item.itemId.isEmpty) continue;
      items.add(item.copyWith(
        issued: issued[item.itemId] ?? 0,
        damaged: damaged[item.itemId] ?? 0,
      ));
    }
    // No formatting/formula rewrites here — formatting is applied once at
    // spreadsheet/section creation, and item formulas are written once when
    // each item is added. loadCategory stays a pure read.
    return CategoryData(tab: tab, items: items);
  }

  /// Appends a new item row, assigning a fresh itemId.
  Future<InventoryItem> addItem(
    String spreadsheetId,
    String tab, {
    required String sno,
    required String detail,
    required String firmName,
    required String price,
    required int quantity,
    String notes = '',
    String imageUrl = '',
    String billNo = '',
    String billDate = '',
  }) async {
    final item = InventoryItem(
      itemId: _uuid.v4(),
      sno: sno.trim(),
      detail: detail.trim(),
      firmName: firmName.trim(),
      price: price.trim(),
      quantity: quantity,
      notes: notes.trim(),
      imageUrl: imageUrl,
      billNo: billNo.trim(),
      billDate: billDate.trim(),
    );
    await _sheets.ensureHeaders(spreadsheetId, tab);
    // Ensure both log tabs exist before writing formulas — formulas referencing
    // a non-existent tab land in a permanent #REF! state in Google Sheets.
    await _sheets.ensureIssueLog(spreadsheetId);
    await _sheets.ensureDamageLog(spreadsheetId);
    final rowIndex = await _sheets.appendRow(
      spreadsheetId,
      tab,
      item.toRow(),
      SheetSchema.itemHeaders.length,
    );
    if (rowIndex != null) {
      await _sheets.writeItemFormulas(spreadsheetId, tab, rowIndex, item.quantity);
    }
    // Appended rows inherit the bold header format — reset data rows to normal.
    await _sheets.unboldDataRows(spreadsheetId, tab);
    return item;
  }

  /// Writes current in-app counts (Total/Issued/Damaged/Available) to the
  /// K–N cells for every item. Called after mutations so the sheet stays
  /// accurate without relying on cross-sheet SUMPRODUCT auto-recalculation.
  Future<void> refreshSheetStats(
          String spreadsheetId, String tab, List<InventoryItem> items) =>
      _sheets.batchWriteItemStats(spreadsheetId, tab, items);

  Future<void> deleteItem(String spreadsheetId, String tab, InventoryItem item) async {
    if (item.rowIndex == null) throw StateError('Cannot delete item without a known row index.');
    await _sheets.deleteRow(spreadsheetId, tab, item.rowIndex!);
  }

  Future<DamageRecord> registerDamage(
    String spreadsheetId,
    String tab, {
    required String itemId,
    required String itemDetail,
    required int quantity,
    required DateTime damagedDate,
    String details = '',
  }) =>
      _damage.recordDamage(
        spreadsheetId,
        categoryTab: tab,
        itemId: itemId,
        itemDetail: itemDetail,
        quantity: quantity,
        damagedDate: damagedDate,
        details: details,
      );
}
