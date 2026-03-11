import 'package:flutter/material.dart';

class DeleteConfirmDialog extends StatelessWidget {
  final String taskName;
  final VoidCallback onConfirm;

  const DeleteConfirmDialog({
    super.key,
    required this.taskName,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String taskName,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        taskName: taskName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete task?'),
      content: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            const TextSpan(text: 'This will permanently delete "'),
            TextSpan(
              text: taskName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: '". This action cannot be undone.'),
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
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
