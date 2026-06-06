import 'package:bloc/bloc.dart';

import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/damage_record.dart';
import '../../../shared/models/issue_record.dart';
import '../../../shared/models/inventory_item.dart';
import '../../issues/data/issue_repository.dart';
import '../data/catalog_repository.dart';
import '../data/damage_repository.dart';

class ItemDetailData {
  ItemDetailData({
    required this.item,
    required this.issues,
    required this.damages,
  });

  final InventoryItem item;
  final List<IssueRecord> issues;
  final List<DamageRecord> damages;
}

class ItemDetailCubit extends Cubit<DataState<ItemDetailData>> {
  ItemDetailCubit(
    this._issues,
    this._damage,
    this._catalog, {
    required this.spreadsheetId,
    required this.tab,
    required this.item,
  }) : super(const DataState());

  final IssueRepository _issues;
  final DamageRepository _damage;
  final CatalogRepository _catalog;
  final String spreadsheetId;
  final String tab;
  final InventoryItem item;

  Future<void> load() async {
    emit(state.copyWith(status: DataStatus.loading, clearError: true));
    try {
      // 3 parallel reads (was 9): logs for history display + single item row
      // for fresh quantity. Issued/damaged counts are computed from the logs
      // we already fetch — no separate loadCategory call needed.
      final results = await Future.wait([
        _issues.readLog(spreadsheetId),     // 2 reads
        _damage.readLog(spreadsheetId),     // 2 reads
        item.rowIndex != null               // 1 read
            ? _catalog.loadSingleItem(spreadsheetId, tab, item.rowIndex!)
            : Future<InventoryItem?>.value(null),
      ]);
      final allIssues = results[0] as List<IssueRecord>;
      final allDamages = results[1] as List<DamageRecord>;
      final freshBase = (results[2] as InventoryItem?) ?? item;

      // Compute counts from the already-fetched logs — zero extra API calls.
      final issuedQty = allIssues
          .where((r) => r.isOpen && r.itemId == item.itemId)
          .fold(0, (s, r) => s + r.quantity);
      final damagedQty = allDamages
          .where((r) => r.isDamaged && r.itemId == item.itemId)
          .fold(0, (s, r) => s + r.quantity);
      final freshItem = freshBase.copyWith(issued: issuedQty, damaged: damagedQty);

      emit(state.copyWith(
        status: DataStatus.ready,
        data: ItemDetailData(
          item: freshItem,
          issues: allIssues
              .where((r) => r.itemId == item.itemId)
              .toList()
              .reversed
              .toList(),
          damages: allDamages
              .where((r) => r.itemId == item.itemId)
              .toList()
              .reversed
              .toList(),
        ),
      ));
    } catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: '$e'));
    }
  }

  /// [returnedQty] == record.quantity → full return.
  /// [returnedQty] <  record.quantity → partial return (open row qty reduced,
  ///   new Returned row appended).
  Future<bool> returnIssue(IssueRecord record, int returnedQty) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      if (returnedQty >= record.quantity) {
        await _issues.markReturned(spreadsheetId, record);
      } else {
        await _issues.partialReturn(spreadsheetId, record, returnedQty);
      }
      await load();
      await _refreshSectionStats();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  /// [discardedQty] == record.quantity → full discard.
  /// [discardedQty] <  record.quantity → partial discard.
  /// Also permanently reduces the item's Quantity by [discardedQty].
  Future<bool> discardDamage(DamageRecord record, int discardedQty) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      if (discardedQty >= record.quantity) {
        await _damage.markDiscarded(spreadsheetId, record);
      } else {
        await _damage.partialDiscard(spreadsheetId, record, discardedQty);
      }
      // Read single item row for fresh quantity (1 read vs 5 for loadCategory).
      final freshItem = item.rowIndex != null
          ? await _catalog.loadSingleItem(spreadsheetId, tab, item.rowIndex!)
          : null;
      if (freshItem != null) {
        final newQty =
            (freshItem.quantity - discardedQty).clamp(0, freshItem.quantity);
        await _catalog.updateItemQty(spreadsheetId, tab, freshItem, newQty);
      }
      await load();
      await _refreshSectionStats();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  /// [repairedQty] == record.quantity → full repair.
  /// [repairedQty] <  record.quantity → partial repair (damaged row qty
  ///   reduced, new Repaired row appended).
  Future<bool> repairDamage(DamageRecord record, int repairedQty) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      if (repairedQty >= record.quantity) {
        await _damage.markRepaired(spreadsheetId, record);
      } else {
        await _damage.partialRepair(spreadsheetId, record, repairedQty);
      }
      await load();
      await _refreshSectionStats();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<void> _refreshSectionStats() async {
    try {
      final data = await _catalog.loadCategory(spreadsheetId, tab);
      await _catalog.refreshSheetStats(spreadsheetId, tab, data.items);
    } catch (_) {}
  }
}
