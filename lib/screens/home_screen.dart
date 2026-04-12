import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../services/sync_service.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/mini_player_bar.dart';
import 'flash_screen.dart';
import 'music_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return isWide
            ? _WideLayout(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                taskProvider: taskProvider,
              )
            : _NarrowLayout(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                taskProvider: taskProvider,
              );
      },
    );
  }
}

// ── Narrow layout (mobile) — bottom nav ───────────────────────

class _NarrowLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final TaskProvider taskProvider;

  const _NarrowLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.taskProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: const [
                _TasksTab(),
                FlashScreen(),
                MusicScreen(),
              ],
            ),
          ),
          // Mini player sits above bottom navigation
          const MiniPlayerBar(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Flash Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Music',
          ),
        ],
      ),
    );
  }
}

// ── Wide layout (desktop/tablet) — rail nav ───────────────────

class _WideLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final TaskProvider taskProvider;

  const _WideLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.taskProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = taskProvider.darkMode;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // ── Side rail ─────────────────────────────────────
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            extended: false,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () =>
                        context.read<TaskProvider>().toggleTheme(),
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                    tooltip: isDark ? 'Light mode' : 'Dark mode',
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist_rounded),
                label: Text('Tasks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.style_outlined),
                selectedIcon: Icon(Icons.style_rounded),
                label: Text('Cards'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: Text('Music'),
              ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: cs.outline),

          // ── Content area ──────────────────────────────────
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: const [
                      _TasksTab(showThemeToggle: false),
                      FlashScreen(),
                      MusicScreen(),
                    ],
                  ),
                ),
                // Mini player above the bottom edge on desktop
                const MiniPlayerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tasks tab ─────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final bool showThemeToggle;
  const _TasksTab({this.showThemeToggle = true});

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<TaskProvider>();
    final tasks     = provider.tasks;
    final total     = provider.totalTasks;
    final completed = provider.completedTasks;
    final progress  = total > 0 ? completed / total : 0.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                // ── Header ─────────────────────────────────
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
                    _SyncButton(
                      status: provider.syncStatus,
                      onTap: () => provider.manualSync(),
                    ),
                    if (showThemeToggle)
                      IconButton(
                        onPressed: () =>
                            context.read<TaskProvider>().toggleTheme(),
                        icon: Icon(
                          provider.darkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        style:
                            IconButton.styleFrom(shape: const CircleBorder()),
                      ),
                  ],
                ),

                // ── Progress bar ────────────────────────────
                if (total > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF23272F)
                              : const Color(0xFFEEEFF2),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Toolbar ────────────────────────────────
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context
                          .read<TaskProvider>()
                          .setSortByDate(!provider.sortByDate),
                      icon: Icon(
                        Icons.swap_vert,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 14),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Task list / empty state ─────────────────
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
    );
  }
}

// ── Sync status button ────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback onTap;

  const _SyncButton({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    switch (status) {
      case SyncStatus.syncing:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color.primary,
            ),
          ),
        );
      case SyncStatus.error:
        return IconButton(
          tooltip: 'Sync failed — tap to retry',
          icon: Icon(Icons.sync_problem_outlined,
              color: color.error, size: 20),
          onPressed: onTap,
          style: IconButton.styleFrom(shape: const CircleBorder()),
        );
      case SyncStatus.success:
      case SyncStatus.idle:
        return IconButton(
          tooltip: 'Sync now',
          icon: Icon(Icons.sync_outlined,
              color: color.onSurfaceVariant, size: 20),
          onPressed: onTap,
          style: IconButton.styleFrom(shape: const CircleBorder()),
        );
    }
  }
}

// ── Empty state ───────────────────────────────────────────────

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
              padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }
}
