import 'package:flutter/material.dart';

class FlashCardFormDialog extends StatefulWidget {
  final String? initialFront;
  final String? initialBack;
  final void Function(String front, String back) onSave;

  const FlashCardFormDialog({
    super.key,
    this.initialFront,
    this.initialBack,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    String? initialFront,
    String? initialBack,
    required void Function(String front, String back) onSave,
  }) {
    showDialog(
      context: context,
      builder: (_) => FlashCardFormDialog(
        initialFront: initialFront,
        initialBack: initialBack,
        onSave: onSave,
      ),
    );
  }

  @override
  State<FlashCardFormDialog> createState() => _FlashCardFormDialogState();
}

class _FlashCardFormDialogState extends State<FlashCardFormDialog> {
  late final TextEditingController _frontCtrl;
  late final TextEditingController _backCtrl;
  final _formKey = GlobalKey<FormState>();
  final _backFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _frontCtrl = TextEditingController(text: widget.initialFront ?? '');
    _backCtrl = TextEditingController(text: widget.initialBack ?? '');
  }

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(_frontCtrl.text.trim(), _backCtrl.text.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialFront != null;
    final accent = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Card' : 'New Card'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Front field
            TextFormField(
              controller: _frontCtrl,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Front',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.text_fields_rounded, color: accent),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) => _backFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            // Back field
            TextFormField(
              controller: _backCtrl,
              focusNode: _backFocus,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Back',
                alignLabelWithHint: true,
                prefixIcon:
                    Icon(Icons.flip_to_back_rounded, color: accent),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
