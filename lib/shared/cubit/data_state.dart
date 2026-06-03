import 'package:equatable/equatable.dart';

enum DataStatus { initial, loading, ready, error }

/// Generic async data container used by feature cubits. Keeps the last [data]
/// while [refreshing] so the UI doesn't flicker on reload.
class DataState<T> extends Equatable {
  const DataState({
    this.status = DataStatus.initial,
    this.data,
    this.error,
    this.refreshing = false,
  });

  final DataStatus status;
  final T? data;
  final String? error;
  final bool refreshing;

  bool get hasData => data != null;

  DataState<T> copyWith({
    DataStatus? status,
    T? data,
    String? error,
    bool? refreshing,
    bool clearError = false,
  }) =>
      DataState<T>(
        status: status ?? this.status,
        data: data ?? this.data,
        error: clearError ? null : (error ?? this.error),
        refreshing: refreshing ?? this.refreshing,
      );

  @override
  List<Object?> get props => [status, data, error, refreshing];
}
