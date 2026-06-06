import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/damage_record.dart';

class DiscardResult {
  const DiscardResult(this.quantity);
  final int quantity;
}

class DiscardItemSheet extends StatefulWidget {
  const DiscardItemSheet({super.key, required this.record});
  final DamageRecord record;

  @override
  State<DiscardItemSheet> createState() => _DiscardItemSheetState();
}

class _DiscardItemSheetState extends State<DiscardItemSheet> {
  bool _partial = false;
  final _controller = TextEditingController();
  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_partial) {
      Navigator.pop(context, DiscardResult(widget.record.quantity));
      return;
    }
    final qty = int.tryParse(_controller.text.trim());
    if (qty == null || qty < 1 || qty > widget.record.quantity) return;
    Navigator.pop(context, DiscardResult(qty));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = widget.record;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(record.itemDetail,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Damaged',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onErrorContainer)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Detail(label: 'Qty',        value: '×${record.quantity}'),
            _Detail(label: 'Damaged on', value: _fmt.format(record.damagedDate)),
            if (record.details.isNotEmpty)
              _Detail(label: 'Details', value: record.details),
            const Divider(height: 28),
            Text('Discard', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Discarded items are permanently removed from inventory.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.delete_sweep_outlined,
              label: 'Discard all  ×${record.quantity}',
              selected: !_partial,
              scheme: scheme,
              onTap: () => setState(() => _partial = false),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.delete_outline,
              label: 'Discard partial',
              selected: _partial,
              scheme: scheme,
              onTap: () => setState(() => _partial = true),
            ),
            if (_partial) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty to discard',
                  helperText: '1 – ${record.quantity}',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError),
              onPressed: _submit,
              child: const Text('Confirm Discard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.scheme,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.error : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                color: selected ? scheme.error : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selected ? scheme.error : null,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal)),
            ),
          ]),
        ),
      );
}
