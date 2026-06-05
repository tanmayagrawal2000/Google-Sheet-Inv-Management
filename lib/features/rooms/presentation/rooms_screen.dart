import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../shared/cubit/data_state.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/data_view.dart';
import '../../auth/cubit/user_session_cubit.dart';
import '../../auth/data/user_repository.dart';
import '../../inventory/data/sheets_repository.dart';
import '../cubit/rooms_cubit.dart';
import '../data/drive_repository.dart';

const _emojiOptions = [
  '📚', '🎵', '🎨', '🖥️', '⚽', '🔧',
  '💊', '📦', '🎓', '🔬', '📷', '🎭',
  '🎮', '🏆', '🖊️', '🎯',
];

String? _leadingEmoji(String name) {
  for (final e in _emojiOptions) {
    if (name.startsWith(e)) return e;
  }
  return null;
}

String _displayName(String name) {
  final emoji = _leadingEmoji(name);
  return emoji == null ? name : name.substring(emoji.length).trim();
}

const _palette = [
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFF42A5F5), // blue
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
  Color(0xFFFF7043), // deep orange
  Color(0xFF26C6DA), // cyan
  Color(0xFFFFCA28), // amber
  Color(0xFF8D6E63), // brown
];

Color _categoryColor(String name) =>
    _palette[name.hashCode.abs() % _palette.length];

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomsCubit(
            getIt<DriveRepository>(),
            getIt<SheetsRepository>(),
            getIt<UserRepository>(),
          )..load(),
      child: const _RoomsView(),
    );
  }
}

class _RoomsView extends StatelessWidget {
  const _RoomsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<RoomsCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
          // Manage Users — admin only
          BlocBuilder<UserSessionCubit, UserSessionState>(
            builder: (context, sessionState) {
              if (sessionState.session?.isAdmin ?? false) {
                return IconButton(
                  tooltip: 'Manage Users',
                  onPressed: () => context.push('/users'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _ThemeSwitcher(),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => context.read<UserSessionCubit>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: BlocBuilder<RoomsCubit, DataState<List<Room>>>(
        builder: (context, state) {
          return DataView<List<Room>>(
            state: state,
            onRetry: () => context.read<RoomsCubit>().load(),
            isEmpty: (rooms) => rooms.isEmpty,
            emptyMessage: 'No categories yet.\nTap "Add category" to create your first.',
            builder: (context, rooms) {
              final session =
                  context.watch<UserSessionCubit>().state.session;
              final visible = session == null
                  ? rooms
                  : rooms
                      .where((r) => session.canRead(r.name))
                      .toList();
              return _CategoryGrid(rooms: visible);
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddCategory(BuildContext context) async {
    final cubit = context.read<RoomsCubit>();
    String? selectedEmoji;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose an icon (optional)',
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiOptions.map((e) {
                    final selected = selectedEmoji == e;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedEmoji = selected ? null : e),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(ctx).colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Center(
                          child: Text(e,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration:
                      const InputDecoration(hintText: 'Category name'),
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    final fullName =
        selectedEmoji != null ? '$selectedEmoji ${name.trim()}' : name.trim();
    await cubit.createRoom(fullName);
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.rooms});
  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 240).clamp(1, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, i) => _CategoryCard(room: rooms[i]),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final emoji = _leadingEmoji(room.name);
    final title = _displayName(room.name);
    final color = _categoryColor(room.name);
    final initial = title.isNotEmpty
        ? title[0].toUpperCase()
        : room.name.isNotEmpty
            ? room.name[0].toUpperCase()
            : '?';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context
            .push('/room/${room.id}?name=${Uri.encodeComponent(room.name)}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored header with emoji or initial letter
            Expanded(
              child: Container(
                color: color.withValues(alpha: 0.18),
                child: Center(
                  child: emoji != null
                      ? Text(emoji, style: const TextStyle(fontSize: 56))
                      : Text(
                          initial,
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                ),
              ),
            ),
            // Title + menu pinned at the bottom
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.isEmpty ? room.name : title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<RoomsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_displayName(room.name)}"?'),
        content: const Text(
            'The spreadsheet will be moved to your Drive trash.'),
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
    if (ok ?? false) await cubit.deleteRoom(room.id);
  }
}

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher();

  static const _modes = [
    (ThemeMode.system, Icons.brightness_auto, 'System'),
    (ThemeMode.light, Icons.light_mode, 'Light'),
    (ThemeMode.dark, Icons.dark_mode, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ThemeCubit>().state;
    final icon = _modes.firstWhere((m) => m.$1 == current).$2;
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(icon),
      onSelected: context.read<ThemeCubit>().setMode,
      itemBuilder: (_) => _modes
          .map((m) => PopupMenuItem(
                value: m.$1,
                child: Row(
                  children: [
                    Icon(m.$2,
                        color: current == m.$1
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    const SizedBox(width: 12),
                    Text(m.$3),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
