import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/flash_category.dart';
import '../models/flash_card.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

class FlashProvider extends ChangeNotifier {
  List<FlashCategory> _categories = [];
  final Map<String, List<FlashCard>> _cards = {};

  List<FlashCategory> get categories => _categories;
  SyncStatus get syncStatus => SyncService.instance.status;

  List<FlashCard> cardsFor(String categoryId) =>
      _cards[categoryId] ?? const [];

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    await _reloadCategories();

    SyncService.instance.statusStream.listen((status) async {
      if (status == SyncStatus.success) {
        await _reloadCategories();
        for (final id in _cards.keys.toList()) {
          _cards[id] = await LocalDb.instance.getCardsForCategory(id);
        }
      }
      notifyListeners();
    });
  }

  Future<void> _reloadCategories() async {
    _categories = await LocalDb.instance.getAllCategories();
    notifyListeners();
  }

  Future<void> loadCards(String categoryId) async {
    _cards[categoryId] =
        await LocalDb.instance.getCardsForCategory(categoryId);
    notifyListeners();
  }

  // ── Manual sync button → pull only ───────────────────────────

  Future<void> manualSync() => SyncService.instance.pullFlash();

  // ── Category CRUD → push after each change ────────────────────

  Future<void> addCategory(String name, int colorValue) async {
    final now = DateTime.now();
    final cat = FlashCategory(
      id: const Uuid().v4(),
      name: name,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    await LocalDb.instance.upsertCategory(cat);
    await _reloadCategories();
    _backgroundPush();
  }

  Future<void> editCategory(String id, String name, int colorValue) async {
    final existing = _categories.firstWhere((c) => c.id == id);
    final updated = existing.copyWith(name: name, colorValue: colorValue);
    await LocalDb.instance.upsertCategory(updated);
    await _reloadCategories();
    _backgroundPush();
  }

  Future<void> deleteCategory(String id) async {
    await LocalDb.instance.deleteCategory(id);
    _cards.remove(id);
    await _reloadCategories();
    _backgroundPush();
  }

  // ── Card CRUD → push after each change ───────────────────────

  Future<void> addCard(String categoryId, String front, String back) async {
    final now = DateTime.now();
    final card = FlashCard(
      id: const Uuid().v4(),
      categoryId: categoryId,
      front: front,
      back: back,
      createdAt: now,
      updatedAt: now,
    );
    await LocalDb.instance.upsertCard(card);
    await loadCards(categoryId);
    await _reloadCategories();
    _backgroundPush();
  }

  Future<void> editCard(
      String categoryId, String cardId, String front, String back) async {
    final existing =
        (_cards[categoryId] ?? []).firstWhere((c) => c.id == cardId);
    final updated = existing.copyWith(front: front, back: back);
    await LocalDb.instance.upsertCard(updated);
    await loadCards(categoryId);
    _backgroundPush();
  }

  Future<void> deleteCard(String categoryId, String cardId) async {
    await LocalDb.instance.deleteCard(cardId);
    await loadCards(categoryId);
    await _reloadCategories();
    _backgroundPush();
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _backgroundPush() {
    SyncService.instance.pushFlash().ignore();
  }
}