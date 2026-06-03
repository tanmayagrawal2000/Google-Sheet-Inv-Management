import 'package:bloc/bloc.dart';

import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/damage_record.dart';
import '../../../shared/models/issue_record.dart';
import '../../../shared/models/inventory_item.dart';
import '../../issues/data/issue_repository.dart';
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
    this._damage, {
    required this.spreadsheetId,
    required this.item,
  }) : super(const DataState());

  final IssueRepository _issues;
  final DamageRepository _damage;
  final String spreadsheetId;
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
}
