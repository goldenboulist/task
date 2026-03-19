import 'package:flutter/material.dart';

class CategoryFormDialog extends StatefulWidget {
  final String? initialName;
  final void Function(String name, int colorValue) onSave;

  const CategoryFormDialog({
    super.key,
    this.initialName,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    String? initialName,
    required void Function(String name, int colorValue) onSave,
  }) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        initialName: initialName,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  final _formKey = GlobalKey<FormState>();

  static const int _blue = 0xFF3571E9;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(_nameCtrl.text.trim(), _blue);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialName != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Category' : 'New Category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}