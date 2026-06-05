import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/issue_record.dart';

class ReturnResult {
  const ReturnResult(this.quantity);
  final int quantity;
}

class ReturnItemSheet extends StatefulWidget {
  const ReturnItemSheet({super.key, required this.record});
  final IssueRecord record;

  @override
  State<ReturnItemSheet> createState() => _ReturnItemSheetState();
}

class _ReturnItemSheetState extends State<ReturnItemSheet> {
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
      Navigator.pop(context, ReturnResult(widget.record.quantity));
      return;
    }
    final qty = int.tryParse(_controller.text.trim());
    if (qty == null || qty < 1 || qty > widget.record.quantity) return;
    Navigator.pop(context, ReturnResult(qty));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = widget.record;
    final isOpen = record.isOpen;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.itemDetail,
                    style: Theme.of(context).textTheme.titleLarge,
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
            const SizedBox(height: 16),

            // ── Details ──────────────────────────────────────────────────────
            _Detail(label: 'Borrower', value: record.borrower),
            _Detail(label: 'Qty issued', value: '×${record.quantity}'),
            _Detail(label: 'Date issued', value: _fmt.format(record.dateIssued)),
            if (record.expectedReturn != null)
              _Detail(
                  label: 'Due date',
                  value: _fmt.format(record.expectedReturn!)),
            if (record.dateReturned != null)
              _Detail(
                  label: 'Returned on',
                  value: _fmt.format(record.dateReturned!)),

            const Divider(height: 28),

            // ── Actions (open only) ──────────────────────────────────────────
            if (isOpen) ...[
              Text('Return',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.done_all,
                label: 'Return all  ×${record.quantity}',
                selected: !_partial,
                scheme: scheme,
                onTap: () => setState(() => _partial = false),
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.call_split,
                label: 'Return partial',
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
                    labelText: 'Qty to return',
                    helperText: '1 – ${record.quantity}',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Confirm Return')),
            ] else ...[
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
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
