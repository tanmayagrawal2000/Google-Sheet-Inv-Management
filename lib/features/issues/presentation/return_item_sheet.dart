import 'package:flutter/material.dart';

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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Return Items', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${record.itemDetail}  ·  ${record.borrower}  ·  ×${record.quantity} issued',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Return All chip
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _partial = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_partial ? scheme.primary : scheme.outlineVariant,
                  width: !_partial ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.done_all,
                      color: !_partial ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Return all  ×${record.quantity}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: !_partial ? scheme.primary : null,
                            fontWeight:
                                !_partial ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Return Partial chip
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _partial = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _partial ? scheme.primary : scheme.outlineVariant,
                  width: _partial ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.call_split,
                      color: _partial ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Return partial',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _partial ? scheme.primary : null,
                            fontWeight:
                                _partial ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Qty field — only visible when partial is selected
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
          FilledButton(
            onPressed: _submit,
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }
}
