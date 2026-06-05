import 'package:bloc/bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/damage_record.dart';
import '../data/catalog_repository.dart';
import '../data/damage_repository.dart';

class DamageLogCubit extends Cubit<DataState<List<DamageRecord>>> {
  DamageLogCubit(this._damage, this._catalog, this.spreadsheetId)
      : super(const DataState<List<DamageRecord>>());

  final DamageRepository _damage;
  final CatalogRepository _catalog;
  final String spreadsheetId;

  Future<void> load() async {
    emit(state.copyWith(
      status: state.hasData ? DataStatus.ready : DataStatus.loading,
      refreshing: true,
      clearError: true,
    ));
    try {
      final log = await _damage.readLog(spreadsheetId);
      emit(state.copyWith(
          status: DataStatus.ready,
          data: log.reversed.toList(),
          refreshing: false));
    } on AppFailure catch (e) {
      emit(state.copyWith(
          status: DataStatus.error, error: e.message, refreshing: false));
    } catch (e) {
      emit(state.copyWith(
          status: DataStatus.error, error: '$e', refreshing: false));
    }
  }

  /// [repairedQty] == record.quantity → full repair.
  /// [repairedQty] <  record.quantity → partial repair.
  Future<bool> repairDamage(DamageRecord record, int repairedQty) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      if (repairedQty >= record.quantity) {
        await _damage.markRepaired(spreadsheetId, record);
      } else {
        await _damage.partialRepair(spreadsheetId, record, repairedQty);
      }
      await load();
      await _refreshSectionStats(record.categoryTab);
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<void> _refreshSectionStats(String tab) async {
    try {
      final data = await _catalog.loadCategory(spreadsheetId, tab);
      await _catalog.refreshSheetStats(spreadsheetId, tab, data.items);
    } catch (_) {}
  }
}
