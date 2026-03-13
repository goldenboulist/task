import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import '../models/task.dart';

// ── Configuration ─────────────────────────────────────────────
const _baseUrl = 'https://maxime-anterion.com/api/sync.php';
const _apiKey  = '7fK2a9Qm4Zx1T8pL6sD3wV0bH5yN9cRA';
// ─────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  SyncService._();
  static final instance = SyncService._();

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Call once from main() after LocalDb is ready.
  Future<void> init() async {
    // Sync immediately on start (if online)
    await sync();

    // Re-sync whenever connectivity is restored
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) await sync();
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }

  Future<void> sync() async {
    if (_status == SyncStatus.syncing) return;
    _emit(SyncStatus.syncing);

    try {
      final db = LocalDb.instance;

      // 1. Collect unsynced local tasks
      final pending = await db.getPendingTasks();

      // 2. Get last successful sync timestamp
      final lastSync = await db.getMeta('last_sync');

      // 3. POST to server
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'last_sync': lastSync,
              'tasks': pending.map((t) => t.toApiJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Sync response: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // 4. Merge server tasks (last-write-wins)
      final serverTasks = (body['tasks'] as List<dynamic>)
          .map((e) => Task.fromApiJson(e as Map<String, dynamic>))
          .toList();
      await db.mergeServerTasks(serverTasks);

      // 5. Mark our pushed tasks as synced
      if (pending.isNotEmpty) {
        await db.markSynced(pending.map((t) => t.id).toList());
      }

      // 6. Clean up synced deleted tasks
      await db.cleanupSyncedDeletedTasks();

      // 7. Save server time as new last_sync
      await db.setMeta('last_sync', body['server_time'] as String);

      _emit(SyncStatus.success);
    } catch (_) {
      _emit(SyncStatus.error);
    }
  }

  void _emit(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
