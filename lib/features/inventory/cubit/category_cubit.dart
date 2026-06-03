import 'package:bloc/bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/inventory_item.dart';
import '../../issues/data/issue_repository.dart';
import '../../rooms/data/drive_repository.dart';
import '../data/catalog_repository.dart';

/// Loads the items of one category tab and handles add/issue/return. After any
/// mutation it reloads so derived Issued/Available counts stay correct.
class CategoryCubit extends Cubit<DataState<CategoryData>> {
  CategoryCubit(
    this._catalog,
    this._issues,
    this._drive, {
    required this.spreadsheetId,
    required this.tab,
  }) : super(const DataState<CategoryData>());

  final CatalogRepository _catalog;
  final IssueRepository _issues;
  final DriveRepository _drive;
  final String spreadsheetId;
  final String tab;

  Future<void> load() async {
    emit(state.copyWith(
      status: state.hasData ? DataStatus.ready : DataStatus.loading,
      refreshing: true,
      clearError: true,
    ));
    try {
      final data = await _catalog.loadCategory(spreadsheetId, tab);
      emit(state.copyWith(status: DataStatus.ready, data: data, refreshing: false));
    } on AppFailure catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: e.message, refreshing: false));
    } catch (e) {
      emit(state.copyWith(status: DataStatus.error, error: '$e', refreshing: false));
    }
  }

  Future<bool> addItem({
    required String sno,
    required String detail,
    required String firmName,
    required String price,
    required int quantity,
    String notes = '',
    String billNo = '',
    String billDate = '',
    XFile? imageFile,
  }) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      String imageUrl = '';
      if (imageFile != null) {
        imageUrl = await _drive.uploadImage(imageFile.path);
      }
      await _catalog.addItem(
        spreadsheetId,
        tab,
        sno: sno,
        detail: detail,
        firmName: firmName,
        price: price,
        quantity: quantity,
        notes: notes,
        imageUrl: imageUrl,
        billNo: billNo,
        billDate: billDate,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> deleteItem(InventoryItem item) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _catalog.deleteItem(spreadsheetId, tab, item);
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> registerDamage({
    required String itemId,
    required String itemDetail,
    required int quantity,
    required DateTime damagedDate,
    String details = '',
  }) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _catalog.registerDamage(
        spreadsheetId,
        tab,
        itemId: itemId,
        itemDetail: itemDetail,
        quantity: quantity,
        damagedDate: damagedDate,
        details: details,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }

  Future<bool> issue({
    required String itemId,
    required String itemDetail,
    required int quantity,
    required String borrower,
    DateTime? expectedReturn,
  }) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      await _issues.issue(
        spreadsheetId,
        categoryTab: tab,
        itemId: itemId,
        itemDetail: itemDetail,
        quantity: quantity,
        borrower: borrower,
        expectedReturn: expectedReturn,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return false;
    }
  }
}
