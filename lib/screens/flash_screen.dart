import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flash_category.dart';
import '../providers/flash_provider.dart';
import '../services/sync_service.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/delete_confirm_dialog.dart';
import 'flash_deck_screen.dart';

class FlashScreen extends StatefulWidget {
  const FlashScreen({super.key});

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends State<FlashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlashProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FlashProvider>();
    final categories = provider.categories;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Flash Cards',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${categories.length} categor${categories.length != 1 ? 'ies' : 'y'}',
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
                      _FlashSyncButton(
                        status: provider.syncStatus,
                        onTap: () =>
                            context.read<FlashProvider>().manualSync(),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () => CategoryFormDialog.show(
                          context,
                          onSave: (name, colorValue) => context
                              .read<FlashProvider>()
                              .addCategory(name, colorValue),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Category'),
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

                  const SizedBox(height: 20),

                  // ── Category grid / empty state ─────────────
                  Expanded(
                    child: categories.isEmpty
                        ? _EmptyCategories(
                            onAdd: () => CategoryFormDialog.show(
                              context,
                              onSave: (name, colorValue) => context
                                  .read<FlashProvider>()
                                  .addCategory(name, colorValue),
                            ),
                          )
                        : _CategoryGrid(categories: categories),
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

// ── Responsive grid ───────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<FlashCategory> categories;
  const _CategoryGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on narrow screens, more on wide desktop screens
        final crossCount = constraints.maxWidth > 480 ? 3 : 2;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) =>
              _CategoryCard(category: categories[index]),
        );
      },
    );
  }
}

// ── Category card ─────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final FlashCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final accent = Color(category.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<FlashProvider>(),
            child: FlashDeckScreen(category: category),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14181F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Color accent bar at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.style_rounded,
                            size: 18, color: accent),
                      ),
                      const Spacer(),
                      _CategoryMenu(category: category, accent: accent),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    category.name,
                    style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.cardCount} card${category.cardCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category menu (edit/delete) ───────────────────────────────

class _CategoryMenu extends StatelessWidget {
  final FlashCategory category;
  final Color accent;
  const _CategoryMenu({required this.category, required this.accent});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline,
                size: 16,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ],
      onSelected: (v) {
        if (v == 'edit') {
          CategoryFormDialog.show(
            context,
            initialName: category.name,
            onSave: (name, colorValue) => context
                .read<FlashProvider>()
                .editCategory(category.id, name, colorValue),
          );
        } else if (v == 'delete') {
          DeleteConfirmDialog.show(
            context,
            taskName: category.name,
            onConfirm: () => context
                .read<FlashProvider>()
                .deleteCategory(category.id),
          );
        }
      },
    );
  }
}

// ── Sync button ───────────────────────────────────────────────

class _FlashSyncButton extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback onTap;
  const _FlashSyncButton({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case SyncStatus.syncing:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        );
      case SyncStatus.error:
        return IconButton(
          tooltip: 'Sync failed — tap to retry',
          icon: Icon(Icons.sync_problem_outlined, color: cs.error, size: 20),
          onPressed: onTap,
          style: IconButton.styleFrom(shape: const CircleBorder()),
        );
      case SyncStatus.success:
      case SyncStatus.idle:
        return IconButton(
          tooltip: 'Sync now',
          icon: Icon(Icons.sync_outlined,
              color: cs.onSurfaceVariant, size: 20),
          onPressed: onTap,
          style: IconButton.styleFrom(shape: const CircleBorder()),
        );
    }
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyCategories extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCategories({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.style_rounded,
                size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a category to organise your cards',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Category'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }
}