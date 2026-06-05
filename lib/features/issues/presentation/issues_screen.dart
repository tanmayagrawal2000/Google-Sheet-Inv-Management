import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injector.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/issue_record.dart';
import '../../../shared/widgets/data_view.dart';
import '../../inventory/data/catalog_repository.dart';
import '../cubit/issues_cubit.dart';
import '../data/issue_repository.dart';
import 'return_item_sheet.dart';

/// The issue ledger for a room, with the ability to mark open issues returned.
class IssuesScreen extends StatelessWidget {
  const IssuesScreen({super.key, required this.spreadsheetId, required this.roomName});

  final String spreadsheetId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => IssuesCubit(
            getIt<IssueRepository>(),
            getIt<CatalogRepository>(),
            spreadsheetId,
          )..load(),
      child: _IssuesView(roomName: roomName),
    );
  }
}

class _IssuesView extends StatelessWidget {
  const _IssuesView({required this.roomName});
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue log'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(roomName, style: Theme.of(context).textTheme.bodySmall),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<IssuesCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<IssuesCubit, DataState<List<IssueRecord>>>(
        builder: (context, state) {
          return DataView<List<IssueRecord>>(
            state: state,
            onRetry: () => context.read<IssuesCubit>().load(),
            isEmpty: (log) => log.isEmpty,
            emptyMessage: 'No issues recorded yet.',
            builder: (context, log) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: log.length,
              itemBuilder: (context, i) => _IssueCard(record: log[i]),
            ),
          );
        },
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.record});
  final IssueRecord record;

  static final _fmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          record.isOpen ? Icons.outbox_outlined : Icons.check_circle_outline,
          color: record.isOpen ? scheme.error : scheme.primary,
        ),
        title: Text('${record.itemDetail} ×${record.quantity}'),
        subtitle: Text(
          [
            record.borrower,
            '${record.categoryTab} · out ${_fmt.format(record.dateIssued)}',
            if (record.expectedReturn != null) 'due ${_fmt.format(record.expectedReturn!)}',
            if (record.dateReturned != null) 'returned ${_fmt.format(record.dateReturned!)}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record.isOpen)
              FilledButton.tonal(
                onPressed: () => _showReturnSheet(context),
                child: const Text('Return'),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _confirmDelete(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReturnSheet(BuildContext context) async {
    final cubit = context.read<IssuesCubit>();
    final result = await showModalBottomSheet<ReturnResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReturnItemSheet(record: record),
    );
    if (result == null) return;
    await cubit.returnIssue(record, result.quantity);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<IssuesCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete log entry?'),
        content: Text(
          'This will permanently remove the "${record.itemDetail}" entry for '
          '${record.borrower} from the sheet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok ?? false) await cubit.deleteRecord(record);
  }
}
