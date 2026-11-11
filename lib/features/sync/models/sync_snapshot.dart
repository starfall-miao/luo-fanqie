import 'dart:convert';

import '../../stats/models/focus_session.dart';
import '../../tasks/models/task.dart';

/// 同步快照：任务（含删除墓碑）与专注记录的完整集合。
///
/// 站点之间采用「任务按 updatedAt 取较新版本、删除墓碑较新则生效、
/// 专注记录按 id 求并集」的合并策略，避免简单的整包覆盖丢数据。
class SyncSnapshot {
  const SyncSnapshot({
    required this.deviceId,
    required this.updatedAt,
    required this.tasks,
    required this.sessions,
    required this.deletedTasks,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String deviceId;
  final DateTime updatedAt;
  final List<Task> tasks;
  final List<FocusSession> sessions;

  /// 任务 id → 删除时间。
  final Map<String, DateTime> deletedTasks;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'deviceId': deviceId,
    'updatedAt': updatedAt.toIso8601String(),
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'deletedTasks': deletedTasks.map(
      (id, deletedAt) => MapEntry(id, deletedAt.toIso8601String()),
    ),
  };

  String encode() => jsonEncode(toJson());

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final tasks = <Task>[];
    final rawTasks = json['tasks'];
    if (rawTasks is List) {
      for (final item in rawTasks.whereType<Map>()) {
        try {
          final task = Task.fromJson(Map<String, dynamic>.from(item));
          if (task.title.isNotEmpty) tasks.add(task);
        } catch (_) {
          // 单条损坏不阻塞整包同步。
        }
      }
    }

    final sessions = <FocusSession>[];
    final rawSessions = json['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions.whereType<Map>()) {
        try {
          final session = FocusSession.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (session.minutes > 0) sessions.add(session);
        } catch (_) {
          // 忽略损坏的单条记录。
        }
      }
    }

    final deleted = <String, DateTime>{};
    final rawDeleted = json['deletedTasks'];
    if (rawDeleted is Map) {
      for (final entry in rawDeleted.entries) {
        if (entry.key is String && entry.value is String) {
          final parsed = DateTime.tryParse(entry.value as String);
          if (parsed != null) deleted[entry.key as String] = parsed;
        }
      }
    }

    return SyncSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      deviceId: json['deviceId'] as String? ?? 'unknown',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      tasks: tasks,
      sessions: sessions,
      deletedTasks: deleted,
    );
  }

  factory SyncSnapshot.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('同步数据格式不正确');
    }
    return SyncSnapshot.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// 合并两端快照，保留本地设备标识。
  static SyncSnapshot merge(SyncSnapshot local, SyncSnapshot remote) {
    final deleted = <String, DateTime>{...local.deletedTasks};
    remote.deletedTasks.forEach((id, deletedAt) {
      final existing = deleted[id];
      if (existing == null || deletedAt.isAfter(existing)) {
        deleted[id] = deletedAt;
      }
    });

    final tasksById = <String, Task>{
      for (final task in local.tasks) task.id: task,
    };
    for (final remoteTask in remote.tasks) {
      final localTask = tasksById[remoteTask.id];
      if (localTask == null ||
          remoteTask.lastModified.isAfter(localTask.lastModified)) {
        tasksById[remoteTask.id] = remoteTask;
      }
    }

    // 墓碑晚于最后修改才代表删除。
    deleted.forEach((id, deletedAt) {
      final task = tasksById[id];
      if (task != null && deletedAt.isAfter(task.lastModified)) {
        tasksById.remove(id);
      }
    });

    final sessionsById = <String, FocusSession>{
      for (final session in local.sessions) session.id: session,
    };
    for (final remoteSession in remote.sessions) {
      sessionsById.putIfAbsent(remoteSession.id, () => remoteSession);
    }

    final sessionList = sessionsById.values.toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    return SyncSnapshot(
      deviceId: local.deviceId,
      updatedAt: DateTime.now(),
      tasks: tasksById.values.toList(),
      sessions: sessionList,
      deletedTasks: deleted,
    );
  }

  /// 只保留最近 90 天的删除墓碑。
  SyncSnapshot pruneTombstones({DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 90));
    final kept = deletedTasks.entries
        .where((entry) => entry.value.isAfter(cutoff))
        .map((entry) => MapEntry(entry.key, entry.value));
    return SyncSnapshot(
      deviceId: deviceId,
      updatedAt: updatedAt,
      tasks: tasks,
      sessions: sessions,
      deletedTasks: Map<String, DateTime>.fromEntries(kept),
      schemaVersion: schemaVersion,
    );
  }
}
