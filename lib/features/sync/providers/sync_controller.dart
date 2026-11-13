// 同步配置与凭据保存在应用私有存储；不同步时不会发出网络请求。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/key_value_storage.dart';
import '../../stats/providers/stats_controller.dart';
import '../../tasks/providers/task_controller.dart';
import '../models/sync_config.dart';
import '../models/sync_snapshot.dart';
import '../services/remote_sync_store.dart';
import '../services/sync_store_factory.dart';

enum SyncStatus { idle, syncing, success, error }

/// 只同步到用户自行填写的 WebDAV / Alist / FTP 文件服务器。
class SyncController extends ChangeNotifier {
  SyncController({
    required TaskController tasks,
    required StatsController stats,
    required KeyValueStorage storage,
    http.Client? httpClient,
    RemoteSyncStore Function(SyncConfig config)? storeFactory,
    DateTime Function()? clock,
    bool scheduleAutoSyncOnStart = true,
  }) : _tasks = tasks,
       _stats = stats,
       _storage = storage,
       _storeFactory = storeFactory,
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _now = clock ?? DateTime.now {
    _config = SyncConfig.decode(_storage.read(_configKey));
    _lastSyncAt = DateTime.tryParse(_storage.read(_lastSyncKey) ?? '');
    _tasks.addListener(_onDataChanged);
    _stats.addListener(_onDataChanged);
    if (scheduleAutoSyncOnStart && isConfigured && _config!.autoSync) {
      _scheduleAutoSync(const Duration(seconds: 3));
    }
  }

  static const _configKey = 'luo_fanqie.sync.file.v1';
  static const _lastSyncKey = 'luo_fanqie.sync.last.v1';
  static const _autoSyncDebounce = Duration(seconds: 4);

  final TaskController _tasks;
  final StatsController _stats;
  final KeyValueStorage _storage;
  final http.Client _http;
  final bool _ownsHttpClient;
  final DateTime Function() _now;
  final RemoteSyncStore Function(SyncConfig config)? _storeFactory;

  SyncConfig? _config;
  DateTime? _lastSyncAt;
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  bool _syncing = false;
  bool _applying = false;
  Timer? _autoSyncTimer;

  SyncConfig? get config => _config;

  bool get isConfigured => _config?.isConfigured == true;

  bool get autoSync => _config?.autoSync ?? false;

  DateTime? get lastSyncAt => _lastSyncAt;

  SyncStatus get status => _status;

  String? get lastError => _lastError;

  bool get isSyncing => _syncing;

  String get statusLabel => switch (_status) {
    SyncStatus.syncing => '同步中…',
    SyncStatus.success => '已同步',
    SyncStatus.error => '同步失败',
    SyncStatus.idle => isConfigured ? '已配置' : '未配置',
  };

  void configure(SyncConfig config) {
    _config = config;
    _lastError = null;
    _status = SyncStatus.idle;
    _saveConfig();
    notifyListeners();
    if (config.autoSync && config.isConfigured) {
      _scheduleAutoSync(const Duration(seconds: 1));
    } else {
      _autoSyncTimer?.cancel();
    }
  }

  void setAutoSync(bool value) {
    final current = _config;
    if (current == null || current.autoSync == value) return;
    _config = current.copyWith(autoSync: value);
    _saveConfig();
    notifyListeners();
    if (value) {
      _scheduleAutoSync(const Duration(seconds: 1));
    } else {
      _autoSyncTimer?.cancel();
    }
  }

  void disconnect() {
    _autoSyncTimer?.cancel();
    _config = null;
    _lastSyncAt = null;
    _status = SyncStatus.idle;
    _lastError = null;
    _storage.delete(_configKey);
    _storage.delete(_lastSyncKey);
    notifyListeners();
  }

  Future<bool> testConnection(SyncConfig config) async {
    if (!config.isConfigured) {
      _lastError = '请先填写服务器地址';
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    }
    RemoteSyncStore? store;
    try {
      _lastError = null;
      notifyListeners();
      store =
          _storeFactory?.call(config) ??
          createSyncStore(config, httpClient: _http);
      await store.test();
      _lastError = null;
      _status = SyncStatus.idle;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = _friendlyError(error);
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    } finally {
      store?.close();
    }
  }

  Future<bool> syncNow() async {
    final config = _config;
    if (config == null || !config.isConfigured) {
      _lastError = '请先在设置中接入 WebDAV、OpenAlist 或 FTP 服务器';
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
      store =
          _storeFactory?.call(config) ??
          createSyncStore(config, httpClient: _http);
      final remoteContent = await store.download();
      final local = _buildLocalSnapshot();
      SyncSnapshot? remote;
      if (remoteContent != null && remoteContent.trim().isNotEmpty) {
        try {
          remote = SyncSnapshot.decode(remoteContent);
        } on FormatException {
          throw const SyncException('远端同步文件格式不正确，请检查是否为落·番茄生成的 JSON');
        }
      }
      final merged = remote == null ? local : SyncSnapshot.merge(local, remote);
      final outgoing = SyncSnapshot(
        deviceId: local.deviceId,
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

      await store.upload(outgoing.encode());
      _lastSyncAt = _now();
      _status = SyncStatus.success;
      unawaited(_storage.write(_lastSyncKey, _lastSyncAt!.toIso8601String()));
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = _friendlyError(error);
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

  void syncOnResume() {
    if (autoSync && isConfigured) {
      _scheduleAutoSync(const Duration(milliseconds: 700));
    }
  }

  SyncSnapshot _buildLocalSnapshot() {
    return SyncSnapshot(
      deviceId: _deviceId(),
      updatedAt: _now(),
      tasks: _tasks.tasks.toList(),
      sessions: _stats.sessions.toList(),
      deletedTasks: Map<String, DateTime>.from(_tasks.deletedTasks),
    ).pruneTombstones(now: _now());
  }

  String _deviceId() {
    const key = 'luo_fanqie.sync.device.v1';
    var id = _storage.read(key);
    if (id == null || id.isEmpty) {
      id = 'device-${_now().microsecondsSinceEpoch}';
      unawaited(_storage.write(key, id));
    }
    return id;
  }

  String _friendlyError(Object error) {
    if (error is SyncException) return error.message;
    if (error is FormatException) return '远端数据格式不正确';
    return '同步失败：$error';
  }

  void _onDataChanged() {
    if (_applying || _syncing || !autoSync || !isConfigured) return;
    _scheduleAutoSync(_autoSyncDebounce);
  }

  void _scheduleAutoSync(Duration delay) {
    if (!autoSync || !isConfigured) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(delay, () {
      if (!autoSync || !isConfigured) return;
      unawaited(syncNow());
    });
  }

  void _saveConfig() {
    final config = _config;
    if (config == null) return;
    unawaited(_storage.write(_configKey, config.encode()));
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
