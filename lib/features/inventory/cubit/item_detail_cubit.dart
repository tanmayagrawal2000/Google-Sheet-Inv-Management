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
      final results = await Future.wait([
        _issues.readLog(spreadsheetId),
        _damage.readLog(spreadsheetId),
      ]);
      final allIssues = results[0] as List<IssueRecord>;
      final allDamages = results[1] as List<DamageRecord>;
      emit(state.copyWith(
        status: DataStatus.ready,
        data: ItemDetailData(
          item: item,
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
