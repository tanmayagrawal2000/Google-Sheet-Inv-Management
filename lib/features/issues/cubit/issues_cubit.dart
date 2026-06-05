import 'package:bloc/bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/issue_record.dart';
import '../../inventory/data/catalog_repository.dart';
import '../data/issue_repository.dart';

/// Loads the issue ledger for a room and handles returns.
class IssuesCubit extends Cubit<DataState<List<IssueRecord>>> {
  IssuesCubit(this._issues, this._catalog, this.spreadsheetId)
      : super(const DataState<List<IssueRecord>>());

  final IssueRepository _issues;
  final CatalogRepository _catalog;
  final String spreadsheetId;

  Future<void> load() async {
    emit(state.copyWith(
      status: state.hasData ? DataStatus.ready : DataStatus.loading,
      refreshing: true,
      clearError: true,
    ));
    try {
      final log = await _issues.readLog(spreadsheetId);
      final sorted = log.reversed.toList();
      emit(state.copyWith(status: DataStatus.ready, data: sorted, refreshing: false));
    } on AppFailure catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: e.message, refreshing: false));
    } catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: '$e', refreshing: false));
    }
  }

  /// [returnedQty] == record.quantity → full return.
  /// [returnedQty] <  record.quantity → partial return (open row qty reduced,
  ///   a new Returned row appended for the returned portion).
  Future<bool> returnIssue(IssueRecord record, int returnedQty) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      if (returnedQty >= record.quantity) {
        await _issues.markReturned(spreadsheetId, record);
      } else {
        await _issues.partialReturn(spreadsheetId, record, returnedQty);
      }
      await load();
      await _refreshSectionStats(record.categoryTab);
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> deleteRecord(IssueRecord record) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _issues.deleteRecord(spreadsheetId, record);
      await load();
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
    } catch (_) {
      // Stats refresh is best-effort — never block the return flow.
    }
  }
}
