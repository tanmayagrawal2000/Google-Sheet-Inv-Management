import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../shared/models/managed_user.dart';
import '../../../shared/models/user_session.dart';
import '../cubit/user_management_cubit.dart';
import '../data/user_repository.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          UserManagementCubit(getIt<UserRepository>())..load(),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatelessWidget {
  const _UserManagementView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add User'),
      ),
      body: BlocBuilder<UserManagementCubit, UserManagementState>(
        builder: (context, state) {
          if (state.loading && state.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () =>
                        context.read<UserManagementCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (state.loading)
                const LinearProgressIndicator(),
              if (state.error != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(state.error!,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer)),
                ),
              Expanded(
                child: state.users.isEmpty
                    ? const Center(
                        child: Text('No users yet. Tap + to add one.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.users.length,
                        itemBuilder: (context, i) => _UserCard(
                          user: state.users[i],
                          categoryNames: state.categoryNames,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final cubit = context.read<UserManagementCubit>();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    var isAdmin = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Admin'),
                subtitle: const Text('Full access to all categories'),
                value: isAdmin,
                onChanged: (v) => setState(() => isAdmin = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (usernameCtrl.text.trim().isNotEmpty &&
                    passwordCtrl.text.isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed ?? false) {
      await cubit.addUser(
        usernameCtrl.text.trim(),
        passwordCtrl.text,
        isAdmin: isAdmin,
      );
    }
    usernameCtrl.dispose();
    passwordCtrl.dispose();
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard(
      {required this.user, required this.categoryNames});

  final ManagedUser user;
  final List<String> categoryNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (user.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Admin',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: scheme.onPrimaryContainer)),
                  ),
                const SizedBox(width: 8),
                // Delete
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete user')),
                  ],
                ),
              ],
            ),

            // ── Category permissions ─────────────────────────────────
            if (categoryNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryNames.map((cat) {
                  final level =
                      user.permissions[cat] ?? AccessLevel.none;
                  return _PermissionChip(
                    categoryName: cat,
                    level: level,
                    onTap: () =>
                        _showPermissionPicker(context, cat, level),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPermissionPicker(
      BuildContext context, String categoryName, AccessLevel current) async {
    final cubit = context.read<UserManagementCubit>();
    final picked = await showDialog<AccessLevel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(categoryName,
            style: Theme.of(context).textTheme.titleSmall),
        children: [
          _AccessOption(label: 'No access', level: AccessLevel.none,
              selected: current == AccessLevel.none),
          _AccessOption(label: 'Read',      level: AccessLevel.read,
              selected: current == AccessLevel.read),
          _AccessOption(label: 'Write',     level: AccessLevel.write,
              selected: current == AccessLevel.write),
        ]
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o.level),
                  child: Row(
                    children: [
                      if (o.selected)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(o.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (picked != null && picked != current) {
      await cubit.updatePermission(user, categoryName, picked);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<UserManagementCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${user.username}"?'),
        content:
            const Text('This user will no longer be able to sign in.'),
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
    if (ok ?? false) await cubit.deleteUser(user);
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip(
      {required this.categoryName,
      required this.level,
      required this.onTap});

  final String categoryName;
  final AccessLevel level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (level) {
      AccessLevel.write => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.edit_outlined
        ),
      AccessLevel.read => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.visibility_outlined
        ),
      AccessLevel.none => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.block_outlined
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              categoryName.length > 16
                  ? '${categoryName.substring(0, 14)}…'
                  : categoryName,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessOption {
  const _AccessOption(
      {required this.label,
      required this.level,
      required this.selected});
  final String label;
  final AccessLevel level;
  final bool selected;
}
