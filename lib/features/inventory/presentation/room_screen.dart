import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/widgets/data_view.dart';
import '../cubit/room_cubit.dart';
import '../data/catalog_repository.dart';

/// Shows the category tabs inside one room (workbook).
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.spreadsheetId, required this.roomName});

  final String spreadsheetId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomCubit(getIt<CatalogRepository>(), spreadsheetId)..load(),
      child: _RoomView(roomName: roomName, spreadsheetId: spreadsheetId),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.roomName, required this.spreadsheetId});
  final String roomName;
  final String spreadsheetId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
        actions: [
          IconButton(
            tooltip: 'Issue log',
            onPressed: () => context.push(
              '/room/$spreadsheetId/log?name=${Uri.encodeComponent(roomName)}',
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<RoomCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Add section'),
      ),
      body: BlocBuilder<RoomCubit, DataState<List<String>>>(
        builder: (context, state) {
          return DataView<List<String>>(
            state: state,
            onRetry: () => context.read<RoomCubit>().load(),
            isEmpty: (tabs) => tabs.isEmpty,
            emptyMessage: 'No sections yet.\nAdd one (e.g. "Piano").',
            builder: (context, tabs) => ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  leading: _SectionAvatar(name: tabs[i]),
                  title: Text(tabs[i]),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _renameCategory(context, tabs[i]);
                      if (v == 'delete') _deleteCategory(context, tabs[i]);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => context.push(
                    '/room/$spreadsheetId/category/${Uri.encodeComponent(tabs[i])}'
                    '?name=${Uri.encodeComponent(roomName)}',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameCategory(BuildContext context, String oldTitle) async {
    final cubit = context.read<RoomCubit>();
    final controller = TextEditingController(text: oldTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.trim().isEmpty || newTitle.trim() == oldTitle) return;
    await cubit.renameCategory(oldTitle, newTitle.trim());
  }

  Future<void> _deleteCategory(BuildContext context, String title) async {
    final cubit = context.read<RoomCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$title"?'),
        content: const Text(
            'This removes the section tab and deletes all its issue and damage log entries. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok ?? false) await cubit.deleteCategory(title);
  }

  Future<void> _addCategory(BuildContext context) async {
    final cubit = context.read<RoomCubit>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Piano'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await cubit.createCategory(name);
  }
}

const _palette = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
  Color(0xFF26C6DA),
  Color(0xFFFFCA28),
  Color(0xFF8D6E63),
];

Color _sectionColor(String name) =>
    _palette[name.hashCode.abs() % _palette.length];

class _SectionAvatar extends StatelessWidget {
  const _SectionAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = _sectionColor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
