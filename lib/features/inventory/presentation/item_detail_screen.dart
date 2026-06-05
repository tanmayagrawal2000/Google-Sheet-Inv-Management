import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injector.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/damage_record.dart';
import '../../../shared/models/inventory_item.dart';
import '../../../shared/models/issue_record.dart';
import '../../issues/data/issue_repository.dart';
import '../cubit/item_detail_cubit.dart';
import '../data/catalog_repository.dart';
import '../data/damage_repository.dart';
import 'widgets/repair_item_sheet.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.spreadsheetId,
    required this.tab,
    required this.item,
  });

  final String spreadsheetId;
  final String tab;
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ItemDetailCubit(
        getIt<IssueRepository>(),
        getIt<DamageRepository>(),
        getIt<CatalogRepository>(),
        spreadsheetId: spreadsheetId,
        tab: tab,
        item: item,
      )..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItemDetailCubit, DataState<ItemDetailData>>(
      builder: (context, state) {
        final cubit = context.read<ItemDetailCubit>();
        final item = cubit.item;
        final imageUrl = _largeImageUrl(item.imageUrl);

        return Scaffold(
          appBar: AppBar(
            title: Text(item.detail.isEmpty ? '(no detail)' : item.detail),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => cubit.load(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              children: [
                // Hero image
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item name
                      Text(
                        item.detail.isEmpty ? '(no detail)' : item.detail,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),

                      // Metadata
                      if ([item.sno, item.firmName, item.price]
                          .any((s) => s.isNotEmpty)) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (item.sno.isNotEmpty) 'SNo ${item.sno}',
                            if (item.firmName.isNotEmpty) item.firmName,
                            if (item.price.isNotEmpty) item.price,
                          ].join('  ·  '),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Stats
                      _StatsRow(item: item),

                      // Bill details
                      if (item.billNo.isNotEmpty || item.billDate.isNotEmpty) ...[
                        const Divider(height: 24),
                        Wrap(
                          spacing: 24,
                          children: [
                            if (item.billNo.isNotEmpty)
                              _InfoChip(label: 'Bill No', value: item.billNo),
                            if (item.billDate.isNotEmpty)
                              _InfoChip(label: 'Bill Date', value: item.billDate),
                          ],
                        ),
                      ],

                      // Notes
                      if (item.notes.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text('Notes',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(item.notes,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],

                      const Divider(height: 32),

                      // Issue history
                      Text('Issue History',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),

                      if (state.status == DataStatus.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (state.status == DataStatus.error)
                        Text(state.error ?? 'Error loading history',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))
                      else if (state.data?.issues.isEmpty ?? true)
                        Text('No issues recorded for this item.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant))
                      else
                        ...state.data!.issues.map((r) => _IssueCard(record: r)),

                      const Divider(height: 32),
                      Text('Damage History',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),

                      if (state.status == DataStatus.ready) ...[
                        if (state.data?.damages.isEmpty ?? true)
                          Text('No damage recorded for this item.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))
                        else
                          ...state.data!.damages
                              .map((r) => _DamageCard(record: r)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _largeImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final dIdx = segments.indexOf('d');
      if (dIdx < 0 || dIdx + 1 >= segments.length) return null;
      return 'https://drive.google.com/thumbnail?id=${segments[dIdx + 1]}&sz=w800';
    } catch (_) {
      return null;
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _StatChip(label: 'Total', value: item.quantity, color: scheme.onSurface),
        _StatChip(label: 'Issued', value: item.issued, color: scheme.tertiary),
        _StatChip(label: 'Damaged', value: item.damaged, color: scheme.error),
        _StatChip(label: 'Available', value: item.available, color: scheme.primary),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _DamageCard extends StatelessWidget {
  const _DamageCard({required this.record});
  final DamageRecord record;

  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDamaged = record.isDamaged;
    final statusColor = isDamaged ? scheme.error : scheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDamaged
                      ? Icons.warning_amber_rounded
                      : Icons.build_circle_outlined,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '×${record.quantity} ${isDamaged ? "damaged" : "repaired"}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: statusColor),
                ),
                const Spacer(),
                Text(_fmt.format(record.damagedDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
              ],
            ),
            if (record.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(record.details,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
            ],
            if (isDamaged) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _showRepairSheet(context),
                  child: const Text('Repair'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRepairSheet(BuildContext context) async {
    final cubit = context.read<ItemDetailCubit>();
    final result = await showModalBottomSheet<RepairResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RepairItemSheet(record: record),
    );
    if (result == null) return;
    await cubit.repairDamage(record, result.quantity);
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.record});
  final IssueRecord record;

  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOpen = record.isOpen;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.borrower,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Returned',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isOpen
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _infoRow(context, Icons.arrow_upward,
                'Issued  ${_fmt.format(record.dateIssued)}  ×${record.quantity}'),
            if (record.expectedReturn != null)
              _infoRow(context, Icons.event,
                  'Due  ${_fmt.format(record.expectedReturn!)}'),
            if (record.dateReturned != null)
              _infoRow(context, Icons.arrow_downward,
                  'Returned  ${_fmt.format(record.dateReturned!)}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      );
}
