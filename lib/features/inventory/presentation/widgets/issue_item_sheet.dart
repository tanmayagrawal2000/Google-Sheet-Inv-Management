import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Result returned from [IssueItemSheet].
class IssueResult {
  IssueResult({required this.quantity, required this.borrower, this.expectedReturn});

  final int quantity;
  final String borrower;
  final DateTime? expectedReturn;
}

/// Form for issuing 1..[maxQuantity] units of an item to a free-text borrower.
class IssueItemSheet extends StatefulWidget {
  const IssueItemSheet({super.key, required this.maxQuantity, required this.itemDetail});

  final int maxQuantity;
  final String itemDetail;

  @override
  State<IssueItemSheet> createState() => _IssueItemSheetState();
}

class _IssueItemSheetState extends State<IssueItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _borrower = TextEditingController();
  late final TextEditingController _quantity =
      TextEditingController(text: '1');
  DateTime? _expectedReturn;

  @override
  void dispose() {
    _borrower.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expectedReturn = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      IssueResult(
        quantity: int.parse(_quantity.text),
        borrower: _borrower.text,
        expectedReturn: _expectedReturn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel = _expectedReturn == null
        ? 'Expected return (optional)'
        : 'Return by ${DateFormat('yyyy-MM-dd').format(_expectedReturn!)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Issue: ${widget.itemDetail}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Up to ${widget.maxQuantity} available',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _borrower,
              decoration: const InputDecoration(labelText: 'Borrower'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter a number ≥ 1';
                if (n > widget.maxQuantity) return 'Only ${widget.maxQuantity} available';
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(dateLabel),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Issue')),
          ],
        ),
      ),
    );
  }
}
