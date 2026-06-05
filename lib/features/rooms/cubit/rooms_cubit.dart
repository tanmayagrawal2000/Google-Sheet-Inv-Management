import 'package:bloc/bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/room.dart';
import '../../auth/data/user_repository.dart';
import '../../inventory/data/sheets_repository.dart';
import '../data/drive_repository.dart';

class RoomsCubit extends Cubit<DataState<List<Room>>> {
  RoomsCubit(this._repo, this._sheets, this._userRepo)
      : super(const DataState<List<Room>>());

  final DriveRepository _repo;
  final SheetsRepository _sheets;
  final UserRepository _userRepo;

  Future<void> load() async {
    emit(state.copyWith(
      status: state.hasData ? DataStatus.ready : DataStatus.loading,
      refreshing: true,
      clearError: true,
    ));
    try {
      final rooms = await _repo.listRooms();
      emit(state.copyWith(
          status: DataStatus.ready, data: rooms, refreshing: false));
    } on AppFailure catch (e) {
      emit(state.copyWith(
          status: DataStatus.error, error: e.message, refreshing: false));
    } catch (e) {
      emit(state.copyWith(
          status: DataStatus.error, error: '$e', refreshing: false));
    }
  }

  Future<Room?> createRoom(String name) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      final room = await _repo.createRoom(name);
      final tabs = await _sheets.listCategoryTabs(room.id);
      for (final tab in tabs) {
        await _sheets.ensureHeaders(room.id, tab);
      }
      await _sheets.initializeSpreadsheet(room.id);
      // Add a column for this category to the Users sheet.
      await _userRepo.addCategoryColumn(room.name);
      final updated = [...?state.data, room]
        ..sort((a, b) => a.name.compareTo(b.name));
      emit(state.copyWith(
          status: DataStatus.ready, data: updated, refreshing: false));
      return room;
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message, refreshing: false));
      return null;
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
      return null;
    }
  }

  Future<void> deleteRoom(String id) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    try {
      // Find the room name before deleting.
      final room =
          state.data?.firstWhere((r) => r.id == id, orElse: () => throw '');
      await _repo.deleteRoom(id);
      if (room != null) {
        await _userRepo.removeCategoryColumn(room.name);
      }
      final updated = [...?state.data]..removeWhere((r) => r.id == id);
      emit(state.copyWith(
          status: DataStatus.ready, data: updated, refreshing: false));
    } catch (e) {
      emit(state.copyWith(error: '$e', refreshing: false));
    }
  }
}
