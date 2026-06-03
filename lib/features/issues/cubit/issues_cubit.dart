import 'package:bloc/bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/issue_record.dart';
import '../data/issue_repository.dart';

/// Loads the issue ledger for a room and handles returns.
class IssuesCubit extends Cubit<DataState<List<IssueRecord>>> {
  IssuesCubit(this._issues, this.spreadsheetId)
      : super(const DataState<List<IssueRecord>>());

  final IssueRepository _issues;
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

  Future<bool> returnIssue(IssueRecord record) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _issues.markReturned(spreadsheetId, record);
      await load();
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
}
