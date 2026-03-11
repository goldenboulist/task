import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/delete_confirm_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasks;
    final total = provider.totalTasks;
    final completed = provider.completedTasks;
    final progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tasks',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$completed of $total completed',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            context.read<TaskProvider>().toggleTheme(),
                        icon: Icon(
                          provider.darkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),

                  // Progress bar
                  if (total > 0) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF23272F)
                            : const Color(0xFFEEEFF2),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Toolbar
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context
                            .read<TaskProvider>()
                            .setSortByDate(!provider.sortByDate),
                        icon: Icon(Icons.swap_vert, size: 16,color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,),
                        label: Text(
                          provider.sortByDate ? 'By due date' : 'By created',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => TaskFormDialog.show(
                          context,
                          onSave: (name, desc, due) =>
                              context.read<TaskProvider>().addTask(name, desc, due),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Task'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Task list or empty state
                  Expanded(
                    child: tasks.isEmpty
                        ? _EmptyState(
                            onAdd: () => TaskFormDialog.show(
                              context,
                              onSave: (name, desc, due) => context
                                  .read<TaskProvider>()
                                  .addTask(name, desc, due),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return TaskCard(
                                task: task,
                                onToggle: () => context
                                    .read<TaskProvider>()
                                    .toggleComplete(task.id),
                                onEdit: () => TaskFormDialog.show(
                                  context,
                                  task: task,
                                  onSave: (name, desc, due) => context
                                      .read<TaskProvider>()
                                      .editTask(task.id, name, desc, due),
                                ),
                                onDelete: () => DeleteConfirmDialog.show(
                                  context,
                                  taskName: task.name,
                                  onConfirm: () => context
                                      .read<TaskProvider>()
                                      .deleteTask(task.id),
                                ),
                              );
                            },
                          ),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first task to get started',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Task'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }
}
