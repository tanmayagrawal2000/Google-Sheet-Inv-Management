import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DamageResult {
  DamageResult({
    required this.quantity,
    required this.damagedDate,
    this.details = '',
  });

  final int quantity;
  final DateTime damagedDate;
  final String details;
}

class DamageItemSheet extends StatefulWidget {
  const DamageItemSheet({
    super.key,
    required this.maxQuantity,
    required this.itemDetail,
  });

  final int maxQuantity;
  final String itemDetail;

  @override
  State<DamageItemSheet> createState() => _DamageItemSheetState();
}

class _DamageItemSheetState extends State<DamageItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController(text: '1');
  final _details = TextEditingController();
  DateTime _damagedDate = DateTime.now();

  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _qty.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _damagedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _damagedDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      DamageResult(
        quantity: int.parse(_qty.text),
        damagedDate: _damagedDate,
        details: _details.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Register Damage', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.itemDetail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty damaged',
                  helperText: 'Max ${widget.maxQuantity}',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter a number ≥ 1';
                  if (n > widget.maxQuantity) return 'Cannot exceed ${widget.maxQuantity}';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Damaged date'),
                  child: Row(
                    children: [
                      Expanded(child: Text(_fmt.format(_damagedDate))),
                      const Icon(Icons.calendar_today_outlined, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText: 'e.g. screen cracked, water damage',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Register')),
            ],
          ),
        ),
      ),
    );
  }
}
