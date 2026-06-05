import 'package:flutter/material.dart';

import '../../../../shared/models/damage_record.dart';

class RepairResult {
  const RepairResult(this.quantity);
  final int quantity;
}

class RepairItemSheet extends StatefulWidget {
  const RepairItemSheet({super.key, required this.record});
  final DamageRecord record;

  @override
  State<RepairItemSheet> createState() => _RepairItemSheetState();
}

class _RepairItemSheetState extends State<RepairItemSheet> {
  bool _partial = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_partial) {
      Navigator.pop(context, RepairResult(widget.record.quantity));
      return;
    }
    final qty = int.tryParse(_controller.text.trim());
    if (qty == null || qty < 1 || qty > widget.record.quantity) return;
    Navigator.pop(context, RepairResult(qty));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = widget.record;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Repair Items', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${record.itemDetail}  ·  ×${record.quantity} damaged',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Repair All
          _OptionTile(
            icon: Icons.build_circle_outlined,
            label: 'Repair all  ×${record.quantity}',
            selected: !_partial,
            scheme: scheme,
            onTap: () => setState(() => _partial = false),
          ),

          const SizedBox(height: 10),

          // Repair Partial
          _OptionTile(
            icon: Icons.build_outlined,
            label: 'Repair partial',
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
                labelText: 'Qty repaired',
                helperText: '1 – ${record.quantity}',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            child: const Text('Confirm Repair'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selected ? scheme.primary : null,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
