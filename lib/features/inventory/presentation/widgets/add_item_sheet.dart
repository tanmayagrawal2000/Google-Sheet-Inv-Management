import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddItemResult {
  AddItemResult({
    required this.sno,
    required this.detail,
    required this.firmName,
    required this.price,
    required this.quantity,
    required this.notes,
    required this.billNo,
    required this.billDate,
    this.imageFile,
  });

  final String sno;
  final String detail;
  final String firmName;
  final String price;
  final int quantity;
  final String notes;
  final String billNo;
  final String billDate;
  final XFile? imageFile;
}

class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key});

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sno = TextEditingController();
  final _detail = TextEditingController();
  final _firmName = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _notes = TextEditingController();
  final _billNo = TextEditingController();
  DateTime? _billDate;
  XFile? _imageFile;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    for (final c in [_sno, _detail, _firmName, _price, _quantity, _notes, _billNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      AddItemResult(
        sno: _sno.text,
        detail: _detail.text,
        firmName: _firmName.text,
        price: _price.text,
        quantity: int.parse(_quantity.text),
        notes: _notes.text,
        billNo: _billNo.text,
        billDate: _billDate != null ? _dateFmt.format(_billDate!) : '',
        imageFile: _imageFile,
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
              Text('Add item', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _sno,
                  decoration: const InputDecoration(labelText: 'SNo')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detail,
                decoration: const InputDecoration(labelText: 'Detail'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _firmName,
                  decoration: const InputDecoration(labelText: 'Firm Name')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  helperText: '1 for serial-tracked unit, N for bulk',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter a number ≥ 1';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                        controller: _billNo,
                        decoration:
                            const InputDecoration(labelText: 'Bill No')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Bill Date'),
                        child: Text(
                          _billDate != null
                              ? _dateFmt.format(_billDate!)
                              : 'Select date',
                          style: _billDate == null
                              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_outlined),
                label: Text(
                    _imageFile == null ? 'Attach photo' : _imageFile!.name),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Add')),
            ],
          ),
        ),
      ),
    );
  }
}
