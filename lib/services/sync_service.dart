import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'local_db.dart';
import '../models/task.dart';

// ── Configuration ─────────────────────────────────────────────
const String _baseUrl = 'https://maxime-anterion.com/api/sync.php';
late final String _apiKey;
// ─────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  SyncService._();
  static final instance = SyncService._();
 
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
 
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;
 
  bool _isPulling  = false;
  bool _isPushing  = false;
  bool _pushQueued = false; // a push was requested while pull was running
 
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
 
  Future<void> init() async {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    _apiKey = dotenv.env['API_KEY'] ?? '';
    
    if (_apiKey.isEmpty) {
      throw Exception('API_KEY not found in environment variables');
    }

    // On first install (empty local DB) pull from server to populate.
    // Otherwise skip startup pull — local data is the source of truth until
    // the user explicitly syncs or makes a change.
    final localTasks = await LocalDb.instance.getAllActiveTasks();
    if (localTasks.isEmpty) await pull();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) await pull();
    });
  }
 
  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
 
  /// PULL — server → local. Never sends local data.
  Future<List<Task>?> pull() async {
    if (_isPulling) return null;
 
    // If a push is in flight let it finish first, then pull
    if (_isPushing) {
      await _waitForPush();
    }
 
    _isPulling = true;
    _emit(SyncStatus.syncing);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'action': 'pull'}),
      ).timeout(const Duration(seconds: 15));
 
      if (response.statusCode != 200) throw Exception('${response.statusCode}');
 
      final serverTasks = _parseTasks(response.body);
      await LocalDb.instance.replaceAllTasks(serverTasks);
      _emit(SyncStatus.success);
      return serverTasks;
    } catch (_) {
      _emit(SyncStatus.error);
      return null;
    } finally {
      _isPulling = false;
      // If a push was requested while we were pulling, run it now
      if (_pushQueued) {
        _pushQueued = false;
        push();
      }
    }
  }
 
  /// PUSH — local → server diff → server returns authoritative list → local.
  Future<List<Task>?> push() async {
    // If a pull is running, queue the push for when it finishes
    if (_isPulling) {
      _pushQueued = true;
      return null;
    }
    if (_isPushing) return null; // already pushing, skip duplicate
 
    _isPushing = true;
    _emit(SyncStatus.syncing);
    try {
      final localTasks = await LocalDb.instance.getAllActiveTasks();
 
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'action': 'push',
          'tasks': localTasks.map((t) => t.toApiJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));
 
      if (response.statusCode != 200) throw Exception('${response.statusCode}');
 
      final serverTasks = _parseTasks(response.body);
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
 
  // ── Helpers ───────────────────────────────────────────────────
 
  List<Task> _parseTasks(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['tasks'] as List<dynamic>)
        .map((e) => Task.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }
 
  /// Wait until the current push finishes (poll every 100 ms).
  Future<void> _waitForPush() async {
    while (_isPushing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
 
  void _emit(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}