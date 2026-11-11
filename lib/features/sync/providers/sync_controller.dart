// 构造函数参数是对外 API，字段保持私有。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/id_utils.dart';
import '../../stats/providers/stats_controller.dart';
import '../../tasks/providers/task_controller.dart';
import '../models/sync_snapshot.dart';
import '../services/gist_sync_client.dart';

enum SyncStatus { idle, syncing, success, error }

/// 跨设备同步控制器。
///
/// 目前使用 GitHub Gist 作为远端，配置与凭据仅保存在本机。
/// 合并策略见 [SyncSnapshot.merge]：任务按最后修改时间、删除按墓碑、
/// 专注记录按 id 求并集。
class SyncController extends ChangeNotifier {
  SyncController({
    required TaskController tasks,
    required StatsController stats,
    required KeyValueStorage storage,
    http.Client? httpClient,
    RemoteSyncStore Function(String token, String? gistId)? storeFactory,
    DateTime Function()? clock,
    bool scheduleAutoSyncOnStart = true,
  }) : _tasks = tasks,
       _stats = stats,
       _storage = storage,
       _storeFactory = storeFactory,
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _now = clock ?? DateTime.now {
    _deviceId = _loadDeviceId();
    _loadConfig();
    _tasks.addListener(_onDataChanged);
    _stats.addListener(_onDataChanged);
    if (scheduleAutoSyncOnStart && _autoSync && isConfigured) {
      _scheduleAutoSync(const Duration(seconds: 3));
    }
  }

  static const _configKey = 'luo_fanqie.sync.config.v1';
  static const _deviceKey = 'luo_fanqie.sync.device.v1';
  static const _autoSyncDebounce = Duration(seconds: 4);

  final TaskController _tasks;
  final StatsController _stats;
  final KeyValueStorage _storage;
  final http.Client _http;
  final bool _ownsHttpClient;
  final DateTime Function() _now;
  final RemoteSyncStore Function(String token, String? gistId)? _storeFactory;

  late String _deviceId;
  String _token = '';
  String? _gistId;
  bool _autoSync = false;
  DateTime? _lastSyncAt;
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  bool _syncing = false;
  bool _applying = false;
  Timer? _autoSyncTimer;

  bool get isConfigured => _token.isNotEmpty;

  bool get autoSync => _autoSync;

  String get token => _token;

  String? get gistId => _gistId;

  DateTime? get lastSyncAt => _lastSyncAt;

  SyncStatus get status => _status;

  String? get lastError => _lastError;

  bool get isSyncing => _syncing;

  String get deviceId => _deviceId;

  String get statusLabel => switch (_status) {
    SyncStatus.syncing => '同步中…',
    SyncStatus.success => '已同步',
    SyncStatus.error => '同步失败',
    SyncStatus.idle => isConfigured ? '已开启' : '未开启',
  };

  void configure({
    required String token,
    String? gistId,
    required bool autoSync,
  }) {
    _token = token.trim();
    final normalizedGistId = gistId?.trim();
    _gistId = normalizedGistId == null || normalizedGistId.isEmpty
        ? null
        : normalizedGistId;
    _autoSync = autoSync;
    _lastError = null;
    _status = SyncStatus.idle;
    _saveConfig();
    notifyListeners();
    if (isConfigured && autoSync) {
      _scheduleAutoSync(const Duration(seconds: 1));
    }
  }

  void setAutoSync(bool value) {
    if (_autoSync == value) return;
    _autoSync = value;
    _saveConfig();
    notifyListeners();
    if (value && isConfigured) {
      _scheduleAutoSync(const Duration(seconds: 1));
    } else {
      _autoSyncTimer?.cancel();
    }
  }

  void disconnect() {
    _autoSyncTimer?.cancel();
    _token = '';
    _gistId = null;
    _autoSync = false;
    _lastSyncAt = null;
    _status = SyncStatus.idle;
    _lastError = null;
    _saveConfig();
    notifyListeners();
  }

  Future<bool> syncNow() async {
    if (!isConfigured) {
      _lastError = '请先填写 GitHub Token';
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    }
    if (_syncing) return false;
    _syncing = true;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    RemoteSyncStore? store;
    try {
      final local = _buildLocalSnapshot();
      store =
          _storeFactory?.call(_token, _gistId) ??
          GistSyncClient(token: _token, gistId: _gistId, httpClient: _http);
      final remote = await store.pull();
      if (remote.gistId != null) _gistId = remote.gistId;
      final merged = remote.snapshot == null
          ? local
          : SyncSnapshot.merge(local, remote.snapshot!);
      final outgoing = SyncSnapshot(
        deviceId: _deviceId,
        updatedAt: _now(),
        tasks: merged.tasks,
        sessions: merged.sessions,
        deletedTasks: merged.pruneTombstones(now: _now()).deletedTasks,
      );

      _applying = true;
      try {
        _tasks.applyMerged(
          tasks: outgoing.tasks,
          deletedTasks: outgoing.deletedTasks,
        );
        _stats.applyMergedSessions(outgoing.sessions);
      } finally {
        _applying = false;
      }

      final savedGistId = await store.push(outgoing);
      _gistId = savedGistId;
      _lastSyncAt = _now();
      _status = SyncStatus.success;
      _saveConfig();
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = error is SyncException ? error.message : '同步失败：$error';
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    } finally {
      store?.close();
      _syncing = false;
      if (_status == SyncStatus.syncing) {
        _status = SyncStatus.idle;
        notifyListeners();
      }
    }
  }

  /// 回到前台时调用；只在自动同步开启时工作。
  void syncOnResume() {
    if (_autoSync && isConfigured) {
      _scheduleAutoSync(const Duration(milliseconds: 600));
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    if (_status == SyncStatus.error) _status = SyncStatus.idle;
    notifyListeners();
  }

  SyncSnapshot _buildLocalSnapshot() {
    return SyncSnapshot(
      deviceId: _deviceId,
      updatedAt: _now(),
      tasks: _tasks.tasks.toList(),
      sessions: _stats.sessions.toList(),
      deletedTasks: Map<String, DateTime>.from(_tasks.deletedTasks),
    ).pruneTombstones(now: _now());
  }

  void _onDataChanged() {
    if (_applying || _syncing || !_autoSync || !isConfigured) return;
    _scheduleAutoSync(_autoSyncDebounce);
  }

  void _scheduleAutoSync(Duration delay) {
    if (!_autoSync || !isConfigured) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(delay, () {
      if (!_autoSync || !isConfigured) return;
      unawaited(syncNow());
    });
  }

  String _loadDeviceId() {
    final stored = _storage.read(_deviceKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final created = newId('device');
    unawaited(_storage.write(_deviceKey, created));
    return created;
  }

  void _loadConfig() {
    final raw = _storage.read(_configKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final config = Map<String, dynamic>.from(decoded);
      _token = config['token'] as String? ?? '';
      _gistId = config['gistId'] as String?;
      _autoSync = config['autoSync'] as bool? ?? false;
      _lastSyncAt = DateTime.tryParse(config['lastSyncAt'] as String? ?? '');
    } catch (_) {
      // 配置损坏时保持未配置状态。
    }
  }

  void _saveConfig() {
    unawaited(
      _storage.write(
        _configKey,
        jsonEncode(<String, dynamic>{
          'token': _token,
          'gistId': _gistId,
          'autoSync': _autoSync,
          'lastSyncAt': _lastSyncAt?.toIso8601String(),
        }),
      ),
    );
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _tasks.removeListener(_onDataChanged);
    _stats.removeListener(_onDataChanged);
    if (_ownsHttpClient) _http.close();
    super.dispose();
  }
}
