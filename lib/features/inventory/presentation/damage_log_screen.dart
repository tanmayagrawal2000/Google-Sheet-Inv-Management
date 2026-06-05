import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injector.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/damage_record.dart';
import '../../../shared/widgets/data_view.dart';
import '../cubit/damage_log_cubit.dart';
import '../data/catalog_repository.dart';
import '../data/damage_repository.dart';
import 'widgets/repair_item_sheet.dart';

class DamageLogScreen extends StatelessWidget {
  const DamageLogScreen(
      {super.key, required this.spreadsheetId, required this.roomName});

  final String spreadsheetId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DamageLogCubit(
        getIt<DamageRepository>(),
        getIt<CatalogRepository>(),
        spreadsheetId,
      )..load(),
      child: _DamageLogView(roomName: roomName),
    );
  }
}

class _DamageLogView extends StatelessWidget {
  const _DamageLogView({required this.roomName});
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damage Log'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(roomName,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<DamageLogCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<DamageLogCubit, DataState<List<DamageRecord>>>(
        builder: (context, state) {
          return DataView<List<DamageRecord>>(
            state: state,
            onRetry: () => context.read<DamageLogCubit>().load(),
            isEmpty: (log) => log.isEmpty,
            emptyMessage: 'No damage recorded yet.',
            builder: (context, log) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: log.length,
              itemBuilder: (context, i) => _DamageLogCard(record: log[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DamageLogCard extends StatelessWidget {
  const _DamageLogCard({required this.record});
  final DamageRecord record;

  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDamaged = record.isDamaged;
    final statusColor = isDamaged ? scheme.error : scheme.primary;

    return Card(
      child: ListTile(
        leading: Icon(
          isDamaged
              ? Icons.warning_amber_rounded
              : Icons.build_circle_outlined,
          color: statusColor,
        ),
        title: Text('${record.itemDetail}  ×${record.quantity}'),
        subtitle: Text(
          [
            record.categoryTab,
            'Damaged ${_fmt.format(record.damagedDate)}',
            if (record.repairDate != null)
              'Repaired ${_fmt.format(record.repairDate!)}',
            if (record.details.isNotEmpty) record.details,
          ].join('  ·  '),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDamaged
                    ? scheme.errorContainer
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isDamaged ? 'Damaged' : 'Repaired',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDamaged
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
              ),
            ),
            if (isDamaged)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton.tonal(
                  onPressed: () => _showRepairSheet(context),
                  child: const Text('Repair'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRepairSheet(BuildContext context) async {
    final cubit = context.read<DamageLogCubit>();
    final result = await showModalBottomSheet<RepairResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RepairItemSheet(record: record),
    );
    if (result == null) return;
    await cubit.repairDamage(record, result.quantity);
  }
}
