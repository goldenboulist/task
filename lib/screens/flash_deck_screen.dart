import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flash_card.dart';
import '../models/flash_category.dart';
import '../providers/flash_provider.dart';
import '../widgets/flash_card_form_dialog.dart';
import '../widgets/delete_confirm_dialog.dart';

class FlashDeckScreen extends StatefulWidget {
  final FlashCategory category;

  const FlashDeckScreen({super.key, required this.category});

  @override
  State<FlashDeckScreen> createState() => _FlashDeckScreenState();
}

class _FlashDeckScreenState extends State<FlashDeckScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlashProvider>().loadCards(widget.category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FlashProvider>();
    final cards = provider.cardsFor(widget.category.id);
    final accent = Color(widget.category.colorValue);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.category.name),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: cards.isEmpty
                ? _EmptyDeck(
                    accent: accent,
                    onAdd: () => _showAddCard(context),
                  )
                : Column(
                    children: [
                      // ── Stats banner ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cards.length} card${cards.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (cards.isNotEmpty)
                              TextButton.icon(
                                onPressed: () =>
                                    _startStudyMode(context, cards, accent),
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 16),
                                label: const Text('Study'),
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // ── Card list ─────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: cards.length,
                          itemBuilder: (context, index) {
                            return _FlippableCard(
                              card: cards[index],
                              accent: accent,
                              onEdit: () => _showEditCard(
                                  context, cards[index]),
                              onDelete: () => DeleteConfirmDialog.show(
                                context,
                                taskName: cards[index].front,
                                onConfirm: () => context
                                    .read<FlashProvider>()
                                    .deleteCard(widget.category.id,
                                        cards[index].id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCard(context),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCard(BuildContext context) {
    FlashCardFormDialog.show(
      context,
      onSave: (front, back) => context
          .read<FlashProvider>()
          .addCard(widget.category.id, front, back),
    );
  }

  void _showEditCard(BuildContext context, FlashCard card) {
    FlashCardFormDialog.show(
      context,
      initialFront: card.front,
      initialBack: card.back,
      onSave: (front, back) => context
          .read<FlashProvider>()
          .editCard(widget.category.id, card.id, front, back),
    );
  }

  void _startStudyMode(
      BuildContext context, List<FlashCard> cards, Color accent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudyModeScreen(
          cards: cards,
          accent: accent,
          categoryName: widget.category.name,
        ),
      ),
    );
  }
}

// ── Flippable card list item ───────────────────────────────────

class _FlippableCard extends StatefulWidget {
  final FlashCard card;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlippableCard({
    required this.card,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<_FlippableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _showingBack = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingBack) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _showingBack = !_showingBack);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final angle = _anim.value * pi;
          final isBack = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: GestureDetector(
              onTap: _flip,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isBack
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _CardContent(
                            label: 'Answer',
                            text: widget.card.back,
                            accent: widget.accent,
                            icon: Icons.flip_to_back_rounded,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
                            isBack: true,
                          ),
                        )
                      : _CardContent(
                          label: 'Question',
                          text: widget.card.front,
                          accent: cs.onSurfaceVariant,
                          icon: Icons.text_fields_rounded,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          isBack: false,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final String label;
  final String text;
  final Color accent;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isBack;

  const _CardContent({
    required this.label,
    required this.text,
    required this.accent,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
    required this.isBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(text,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                'Tap to flip',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 16),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 16),
                SizedBox(width: 8),
                Text('Delete'),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
        ),
      ],
    );
  }
}

// ── Empty deck ────────────────────────────────────────────────

class _EmptyDeck extends StatelessWidget {
  final Color accent;
  final VoidCallback onAdd;
  const _EmptyDeck({required this.accent, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.style_rounded, size: 32, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            'No cards yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first card to start memorising',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Card'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
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

// ── Study mode ────────────────────────────────────────────────

class _StudyModeScreen extends StatefulWidget {
  final List<FlashCard> cards;
  final Color accent;
  final String categoryName;

  const _StudyModeScreen({
    required this.cards,
    required this.accent,
    required this.categoryName,
  });

  @override
  State<_StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<_StudyModeScreen>
    with SingleTickerProviderStateMixin {
  late List<FlashCard> _shuffled;
  int _index = 0;
  bool _showingBack = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _shuffled = [...widget.cards]..shuffle(Random());
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingBack) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _showingBack = !_showingBack);
  }

  void _next() {
    if (_index >= _shuffled.length - 1) {
      setState(() => _done = true);
    } else {
      if (_showingBack) {
        _ctrl.reverse();
        setState(() => _showingBack = false);
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _index++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _done ? _buildDone(context) : _buildCard(context, isDark, cs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, ColorScheme cs) {
    final card = _shuffled[_index];
    return Column(
      children: [
        // Progress
        Row(
          children: [
            Text(
              '${_index + 1} / ${_shuffled.length}',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _shuffled.length,
                  color: widget.accent,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? const Color(0xFF23272F)
                      : const Color(0xFFEEEFF2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Flip card
        Expanded(
          child: GestureDetector(
            onTap: _flip,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final angle = _anim.value * pi;
                final isBack = angle > pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14181F)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isBack
                            ? widget.accent.withValues(alpha: 0.4)
                            : cs.outline,
                        width: isBack ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isBack ? widget.accent : Colors.black)
                              .withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _StudyCardFace(
                              label: 'ANSWER',
                              text: card.back,
                              accent: widget.accent,
                            ),
                          )
                        : _StudyCardFace(
                            label: 'QUESTION',
                            text: card.front,
                            accent: cs.onSurfaceVariant,
                          ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hint
        if (!_showingBack)
          Text(
            'Tap card to reveal answer',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: 16),
        // Next button
        if (_showingBack)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _index >= _shuffled.length - 1
                    ? 'Finish'
                    : 'Next card',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 44, color: widget.accent),
          ),
          const SizedBox(height: 20),
          Text(
            'Well done!',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You reviewed all ${_shuffled.length} cards.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to deck'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _shuffled.shuffle(Random());
                    _index = 0;
                    _showingBack = false;
                    _done = false;
                    _ctrl.reset();
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Study again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyCardFace extends StatelessWidget {
  final String label;
  final String text;
  final Color accent;

  const _StudyCardFace({
    required this.label,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}
