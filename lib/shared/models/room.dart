import 'package:equatable/equatable.dart';

/// A "room" / block — backed by a single Google Spreadsheet (workbook) living
/// inside the app's Drive folder.
class Room extends Equatable {
  const Room({
    required this.id,
    required this.name,
    this.modifiedTime,
  });

  /// Drive file id of the spreadsheet.
  final String id;

  /// Spreadsheet name shown on the home grid (e.g. "Music Room").
  final String name;

  final DateTime? modifiedTime;

  @override
  List<Object?> get props => [id, name, modifiedTime];
}
