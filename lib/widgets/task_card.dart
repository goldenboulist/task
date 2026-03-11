import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isHovered = false;

  String _dueDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('MMM d, yyyy').format(date);
  }

  Color _dueDateColor(DateTime date, bool completed, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (completed) return colorScheme.onSurface.withValues(alpha: 0.4);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(today)) return const Color(0xFFEF4444); // overdue
    if (d == today) return const Color(0xFFF59E0B); // due today
    return colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: _isHovered ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          onHover: (value) {
            setState(() {
              _isHovered = value;
            });
          },
          child: Opacity(
            opacity: widget.task.completed ? 0.4 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: widget.task.completed,
                        onChanged: (_) => widget.onToggle(),
                        shape: const CircleBorder(),
                        side: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: widget.task.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: widget.task.completed
                                ? colorScheme.onSurface.withValues(alpha: 0.4)
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (widget.task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: widget.task.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (widget.task.dueDate != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: _dueDateColor(
                                    widget.task.dueDate!, widget.task.completed, context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _dueDateLabel(widget.task.dueDate!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _dueDateColor(
                                      widget.task.dueDate!, widget.task.completed, context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: widget.onEdit,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: widget.onDelete,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}