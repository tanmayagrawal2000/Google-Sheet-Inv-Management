import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/inventory_item.dart';
import '../../../shared/widgets/data_view.dart';
import '../../issues/data/issue_repository.dart';
import '../../rooms/data/drive_repository.dart';
import '../cubit/category_cubit.dart';
import '../data/catalog_repository.dart';
import 'widgets/add_item_sheet.dart';
import 'widgets/damage_item_sheet.dart';
import 'widgets/issue_item_sheet.dart';

/// Items within one category tab, with Total/Issued/Available summary.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({
    super.key,
    required this.spreadsheetId,
    required this.tab,
    required this.roomName,
  });

  final String spreadsheetId;
  final String tab;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CategoryCubit(
        getIt<CatalogRepository>(),
        getIt<IssueRepository>(),
        getIt<DriveRepository>(),
        spreadsheetId: spreadsheetId,
        tab: tab,
      )..load(),
      child: _CategoryView(
          spreadsheetId: spreadsheetId, tab: tab, roomName: roomName),
    );
  }
}

class _CategoryView extends StatelessWidget {
  const _CategoryView(
      {required this.spreadsheetId,
      required this.tab,
      required this.roomName});
  final String spreadsheetId;
  final String tab;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tab),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(roomName, style: Theme.of(context).textTheme.bodySmall),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<CategoryCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: BlocBuilder<CategoryCubit, DataState<CategoryData>>(
        builder: (context, state) {
          return Column(
            children: [
              if (state.hasData) _SummaryBar(data: state.data!),
              Expanded(
                child: DataView<CategoryData>(
                  state: state,
                  onRetry: () => context.read<CategoryCubit>().load(),
                  isEmpty: (d) => d.items.isEmpty,
                  emptyMessage: 'No items yet.\nTap "Add item".',
                  builder: (context, data) => ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.items.length,
                    itemBuilder: (context, i) => _ItemCard(
                      item: data.items[i],
                      spreadsheetId: spreadsheetId,
                      tab: tab,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final cubit = context.read<CategoryCubit>();
    final result = await showModalBottomSheet<AddItemResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddItemSheet(),
    );
    if (result == null) return;
    await cubit.addItem(
      sno: result.sno,
      detail: result.detail,
      firmName: result.firmName,
      price: result.price,
      quantity: result.quantity,
      notes: result.notes,
      billNo: result.billNo,
      billDate: result.billDate,
      imageFile: result.imageFile,
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.data});
  final CategoryData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          stat('Total', data.totalUnits, scheme.onSurface),
          stat('Issued', data.issuedUnits, scheme.tertiary),
          stat('Damaged', data.damagedUnits, scheme.error),
          stat('Available', data.availableUnits, scheme.primary),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard(
      {required this.item,
      required this.spreadsheetId,
      required this.tab});
  final InventoryItem item;
  final String spreadsheetId;
  final String tab;

  @override
  Widget build(BuildContext context) {
    final canIssue = item.available > 0;
    final thumb = item.thumbnailUrl;
    return Card(
      child: ListTile(
        onTap: () => context.push(
          '/room/$spreadsheetId/category/${Uri.encodeComponent(tab)}/item',
          extra: item,
        ),
        leading: thumb != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  thumb,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
                ),
              )
            : null,
        title: Text(item.detail.isEmpty ? '(no detail)' : item.detail),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ([item.sno, item.firmName, item.price]
                .any((s) => s.isNotEmpty))
              Text(
                [
                  if (item.sno.isNotEmpty) 'SNo ${item.sno}',
                  if (item.firmName.isNotEmpty) item.firmName,
                  if (item.price.isNotEmpty) item.price,
                ].join(' · '),
              ),
            const SizedBox(height: 6),
            _ItemStats(item: item),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(
              onPressed: canIssue ? () => _issue(context) : null,
              child: const Text('Issue'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'addqty') _addQty(context);
                if (v == 'damaged') _markDamaged(context);
                if (v == 'delete') _confirmDelete(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'addqty', child: Text('Add qty')),
                PopupMenuItem(value: 'damaged', child: Text('Mark damaged')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _issue(BuildContext context) async {
    final cubit = context.read<CategoryCubit>();
    final result = await showModalBottomSheet<IssueResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => IssueItemSheet(maxQuantity: item.available, itemDetail: item.detail),
    );
    if (result == null) return;
    await cubit.issue(
      itemId: item.itemId,
      itemDetail: item.detail,
      quantity: result.quantity,
      borrower: result.borrower,
      expectedReturn: result.expectedReturn,
    );
  }

  Future<void> _addQty(BuildContext context) async {
    final cubit = context.read<CategoryCubit>();
    final controller = TextEditingController();
    final extra = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Units to add',
            helperText: 'Current total: ${item.quantity}',
          ),
          onSubmitted: (_) {
            final v = int.tryParse(controller.text.trim());
            if (v != null && v > 0) Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (extra != null) await cubit.addQty(item, extra);
  }

  Future<void> _markDamaged(BuildContext context) async {
    final cubit = context.read<CategoryCubit>();
    final result = await showModalBottomSheet<DamageResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DamageItemSheet(
        maxQuantity: item.quantity,
        itemDetail: item.detail,
      ),
    );
    if (result == null) return;
    await cubit.registerDamage(
      itemId: item.itemId,
      itemDetail: item.detail,
      quantity: result.quantity,
      damagedDate: result.damagedDate,
      details: result.details,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CategoryCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.detail.isEmpty ? 'this item' : item.detail}"?'),
        content: const Text('This will permanently remove the row from the sheet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok ?? false) await cubit.deleteItem(item);
  }
}

class _ItemStats extends StatelessWidget {
  const _ItemStats({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _Stat(label: 'Total', value: item.quantity, color: scheme.onSurface),
        const SizedBox(width: 12),
        _Stat(label: 'Issued', value: item.issued, color: scheme.tertiary),
        const SizedBox(width: 12),
        _Stat(label: 'Damaged', value: item.damaged, color: scheme.error),
        const SizedBox(width: 12),
        _Stat(label: 'Available', value: item.available, color: scheme.primary),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
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
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
