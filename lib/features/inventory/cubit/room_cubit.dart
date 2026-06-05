import 'package:bloc/bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../data/catalog_repository.dart';

/// Lists the category tabs within a single room (workbook) and creates new ones.
class RoomCubit extends Cubit<DataState<List<String>>> {
  RoomCubit(this._catalog, this.spreadsheetId) : super(const DataState<List<String>>());

  final CatalogRepository _catalog;
  final String spreadsheetId;

  Future<void> load() async {
    emit(state.copyWith(
      status: state.hasData ? DataStatus.ready : DataStatus.loading,
      refreshing: true,
      clearError: true,
    ));
    try {
      final tabs = await _catalog.listCategories(spreadsheetId);
      emit(state.copyWith(status: DataStatus.ready, data: tabs, refreshing: false));
    } on AppFailure catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: e.message, refreshing: false));
    } catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: '$e', refreshing: false));
    }
  }

  Future<bool> createCategory(String title) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _catalog.createCategory(spreadsheetId, title);
      await load();
      return true;
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message, refreshing: false));
      return false;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> renameCategory(String oldTitle, String newTitle) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _catalog.renameCategory(spreadsheetId, oldTitle, newTitle);
      await load();
      return true;
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message, refreshing: false));
      return false;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> deleteCategory(String title) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _catalog.deleteCategory(spreadsheetId, title);
      await load();
      return true;
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message, refreshing: false));
      return false;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }
}
