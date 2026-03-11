import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? task;
  final void Function(String name, String description, DateTime? dueDate)
      onSave;

  const TaskFormDialog({super.key, this.task, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    Task? task,
    required void Function(String name, String description, DateTime? dueDate)
        onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TaskFormDialog(task: task, onSave: onSave),
    );
  }

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  DateTime? _dueDate;
  String _nameError = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.task?.name ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _dueDate = widget.task?.dueDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Task name is required');
      return;
    }
    widget.onSave(name, _descCtrl.text.trim(), _dueDate);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Task' : 'New Task'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit
                  ? 'Update your task details below.'
                  : 'Fill in the details to create a new task.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Task name
            const _FieldLabel(label: 'Task Name', required: true),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                errorText: _nameError.isNotEmpty ? _nameError : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (_) {
                if (_nameError.isNotEmpty) {
                  setState(() => _nameError = '');
                }
              },
            ),
            const SizedBox(height: 16),

            // Description
            const _FieldLabel(label: 'Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add more details (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Due date
            const _FieldLabel(label: 'Due Date'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                _dueDate != null
                    ? DateFormat('MMM d, yyyy').format(_dueDate!)
                    : 'Pick a date (optional)',
                style: TextStyle(
                  color: _dueDate != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_dueDate != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _dueDate = null),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Clear date',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(isEdit ? 'Save Changes' : 'Add Task'),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        text: label,
        style: theme.textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w500),
        children: required
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              ]
            : [],
      ),
    );
  }
}