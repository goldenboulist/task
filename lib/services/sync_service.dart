import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'local_db.dart';
import '../models/task.dart';
import '../models/flash_category.dart';
import '../models/flash_card.dart';

// ── Configuration ─────────────────────────────────────────────
const String _taskUrl  = 'https://maxime-anterion.com/api/sync.php';
const String _flashUrl = 'https://maxime-anterion.com/api/flash_sync.php';
late final String _apiKey;
// ─────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

/// Result from a flash sync operation.
class FlashSyncResult {
  final List<FlashCategory> categories;
  final List<FlashCard> cards;
  const FlashSyncResult(this.categories, this.cards);
}

class SyncService {
  SyncService._();
  static final instance = SyncService._();

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  // ── Task concurrency guards ───────────────────────────────────
  bool _isPulling  = false;
  bool _isPushing  = false;
  bool _pushQueued = false;

  // ── Flash concurrency guards ──────────────────────────────────
  bool _isFlashPulling  = false;
  bool _isFlashPushing  = false;
  bool _flashPushQueued = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void> init() async {
    await dotenv.load(fileName: ".env");
    _apiKey = dotenv.env['API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('API_KEY not found in environment variables');
    }

    // On first install pull from server to populate local DB
    final localTasks = await LocalDb.instance.getAllActiveTasks();
    if (localTasks.isEmpty) await pull();

    final localCategories = await LocalDb.instance.getAllCategories();
    if (localCategories.isEmpty) await pullFlash();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        await pull();
        await pullFlash();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }

  // ════════════════════════════════════════════════════════════
  //  TASK SYNC
  // ════════════════════════════════════════════════════════════

  /// PULL tasks: server → local.
  Future<List<Task>?> pull() async {
    if (_isPulling) return null;
    if (_isPushing) await _waitForPush();

    _isPulling = true;
    _emit(SyncStatus.syncing);
    try {
      final response = await _post(_taskUrl, {'action': 'pull'});
      final serverTasks = _parseTasks(response);
      await LocalDb.instance.replaceAllTasks(serverTasks);
      _emit(SyncStatus.success);
      return serverTasks;
    } catch (_) {
      _emit(SyncStatus.error);
      return null;
    } finally {
      _isPulling = false;
      if (_pushQueued) {
        _pushQueued = false;
        push();
      }
    }
  }

  /// PUSH tasks: local → server diff → server returns authoritative list → local.
  Future<List<Task>?> push() async {
    if (_isPulling) { _pushQueued = true; return null; }
    if (_isPushing) return null;

    _isPushing = true;
    _emit(SyncStatus.syncing);
    try {
      final localTasks = await LocalDb.instance.getAllActiveTasks();
      final response = await _post(_taskUrl, {
        'action': 'push',
        'tasks': localTasks.map((t) => t.toApiJson()).toList(),
      });
      final serverTasks = _parseTasks(response);
      await LocalDb.instance.replaceAllTasks(serverTasks);
      _emit(SyncStatus.success);
      return serverTasks;
    } catch (_) {
      _emit(SyncStatus.error);
      return null;
    } finally {
      _isPushing = false;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  FLASH SYNC
  // ════════════════════════════════════════════════════════════

  /// PULL flash data: server → local.
  Future<FlashSyncResult?> pullFlash() async {
    if (_isFlashPulling) return null;
    if (_isFlashPushing) await _waitForFlashPush();

    _isFlashPulling = true;
    _emit(SyncStatus.syncing);
    try {
      final body = await _post(_flashUrl, {'action': 'pull'});
      final result = _parseFlash(body);
      await LocalDb.instance
          .replaceAllFlashData(result.categories, result.cards);
      _emit(SyncStatus.success);
      return result;
    } catch (_) {
      _emit(SyncStatus.error);
      return null;
    } finally {
      _isFlashPulling = false;
      if (_flashPushQueued) {
        _flashPushQueued = false;
        pushFlash();
      }
    }
  }

  /// PUSH flash data: local → server diff → server returns authoritative list → local.
  Future<FlashSyncResult?> pushFlash() async {
    if (_isFlashPulling) { _flashPushQueued = true; return null; }
    if (_isFlashPushing) return null;

    _isFlashPushing = true;
    _emit(SyncStatus.syncing);
    try {
      final categories = await LocalDb.instance.getAllCategories();
      // Collect all cards across all categories
      final List<FlashCard> allCards = [];
      for (final cat in categories) {
        allCards.addAll(
            await LocalDb.instance.getCardsForCategory(cat.id));
      }

      final body = await _post(_flashUrl, {
        'action': 'push',
        'categories': categories.map((c) => c.toApiJson()).toList(),
        'cards': allCards.map((c) => c.toApiJson()).toList(),
      });

      final result = _parseFlash(body);
      await LocalDb.instance
          .replaceAllFlashData(result.categories, result.cards);
      _emit(SyncStatus.success);
      return result;
    } catch (_) {
      _emit(SyncStatus.error);
      return null;
    } finally {
      _isFlashPushing = false;
    }
  }

  // ── Shared HTTP helper ────────────────────────────────────────

  Future<String> _post(String url, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.body;
  }

  // ── Parsers ───────────────────────────────────────────────────

  List<Task> _parseTasks(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['tasks'] as List<dynamic>)
        .map((e) => Task.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  FlashSyncResult _parseFlash(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final categories = (json['categories'] as List<dynamic>)
        .map((e) => FlashCategory.fromApiJson(e as Map<String, dynamic>))
        .toList();
    final cards = (json['cards'] as List<dynamic>)
        .map((e) => FlashCard.fromApiJson(e as Map<String, dynamic>))
        .toList();
    return FlashSyncResult(categories, cards);
  }

  // ── Concurrency helpers ───────────────────────────────────────

  Future<void> _waitForPush() async {
    while (_isPushing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _waitForFlashPush() async {
    while (_isFlashPushing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _emit(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
