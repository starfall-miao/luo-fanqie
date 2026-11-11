import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/features/stats/models/focus_session.dart';
import 'package:luo_fanqie_app/features/stats/providers/stats_controller.dart';
import 'package:luo_fanqie_app/features/sync/models/sync_snapshot.dart';
import 'package:luo_fanqie_app/features/sync/providers/sync_controller.dart';
import 'package:luo_fanqie_app/features/sync/services/gist_sync_client.dart';
import 'package:luo_fanqie_app/features/tasks/models/task.dart';
import 'package:luo_fanqie_app/features/tasks/providers/task_controller.dart';

void main() {
  final now = DateTime(2026, 11, 11, 12);

  Task task(
    String id, {
    required String title,
    required DateTime updatedAt,
    bool done = false,
  }) {
    return Task(
      id: id,
      title: title,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: updatedAt,
      done: done,
    );
  }

  FocusSession session(String id, {int minutes = 25}) {
    return FocusSession(
      id: id,
      taskTitle: '测试任务',
      startedAt: now.subtract(Duration(minutes: minutes)),
      endedAt: now,
      minutes: minutes,
    );
  }

  SyncSnapshot snapshot({
    required List<Task> tasks,
    List<FocusSession> sessions = const [],
    Map<String, DateTime> deleted = const {},
    String device = 'local',
  }) {
    return SyncSnapshot(
      deviceId: device,
      updatedAt: now,
      tasks: tasks,
      sessions: sessions,
      deletedTasks: deleted,
    );
  }

  group('同步快照合并', () {
    test('取较新的任务版本，并按 id 合并专注记录', () {
      final local = snapshot(
        tasks: [
          task('a', title: '本机的旧版本', updatedAt: now),
          task('b', title: '只在本机', updatedAt: now),
        ],
        sessions: [session('s1'), session('s2')],
      );
      final remote = snapshot(
        device: 'remote',
        tasks: [
          task(
            'a',
            title: '另一台设备的新版本',
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
          task('c', title: '只在远端', updatedAt: now),
        ],
        sessions: [session('s2'), session('s3')],
      );

      final merged = SyncSnapshot.merge(local, remote);
      expect(merged.tasks, hasLength(3));
      expect(
        merged.tasks.firstWhere((task) => task.id == 'a').title,
        '另一台设备的新版本',
      );
      expect(merged.tasks.map((task) => task.id), containsAll(['a', 'b', 'c']));
      expect(merged.sessions, hasLength(3));
      expect(
        merged.sessions.map((session) => session.id),
        containsAll(['s1', 's2', 's3']),
      );
      expect(merged.deviceId, 'local');
    });

    test('较新的删除墓碑会覆盖旧任务', () {
      final local = snapshot(
        tasks: [task('a', title: '本该删除', updatedAt: now)],
        deleted: {'a': now.add(const Duration(minutes: 1))},
      );
      final remote = snapshot(
        tasks: [
          task(
            'a',
            title: '另一台设备的旧版本',
            updatedAt: now.subtract(const Duration(minutes: 1)),
          ),
          task('b', title: '保留的任务', updatedAt: now),
        ],
      );

      final merged = SyncSnapshot.merge(local, remote);
      expect(merged.tasks.map((task) => task.id), isNot(contains('a')));
      expect(merged.tasks.map((task) => task.id), contains('b'));
    });

    test('任务修改晚于删除时会恢复', () {
      final local = snapshot(
        tasks: [
          task(
            'a',
            title: '重新编辑过的任务',
            updatedAt: now.add(const Duration(minutes: 2)),
          ),
        ],
        deleted: {'a': now},
      );
      final merged = SyncSnapshot.merge(
        local,
        snapshot(tasks: const [], deleted: {'a': now}),
      );
      expect(merged.tasks.map((task) => task.id), contains('a'));
    });

    test('墓碑超过 90 天会被清理', () {
      final merged = snapshot(
        tasks: const [],
        deleted: {'old': now.subtract(const Duration(days: 100))},
      ).pruneTombstones(now: now);
      expect(merged.deletedTasks, isEmpty);
    });
  });

  group('Gist 同步客户端', () {
    test('没有远端数据时返回空快照', () async {
      final client = GistSyncClient(
        token: 'token',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/gists');
          expect(request.headers['Authorization'], 'Bearer token');
          return http.Response('[]', 200);
        }),
      );
      final remote = await client.pull();
      expect(remote.snapshot, isNull);
      expect(remote.gistId, isNull);
      client.close();
    });

    test('指定 Gist 时读取并解析快照', () async {
      final remoteSnapshot = snapshot(
        tasks: [task('a', title: '远端任务', updatedAt: now)],
      );
      final client = GistSyncClient(
        token: 'token',
        gistId: 'gist-1',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/gists/gist-1');
          return http.Response(
            jsonEncode({
              'files': {
                'luo-fanqie-sync.json': {
                  'content': remoteSnapshot.encode(),
                  'truncated': false,
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final remote = await client.pull();
      expect(remote.gistId, 'gist-1');
      expect(remote.snapshot!.tasks.single.title, '远端任务');
      client.close();
    });

    test('首次推送会创建私密 Gist 并返回 id', () async {
      var created = false;
      final client = GistSyncClient(
        token: 'token',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') return http.Response('[]', 200);
          expect(request.method, 'POST');
          expect(request.url.path, '/gists');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['public'], isFalse);
          expect(body['description'], contains('落·番茄'));
          created = true;
          return http.Response(jsonEncode({'id': 'new-gist'}), 201);
        }),
      );
      final id = await client.push(snapshot(tasks: const []));
      expect(created, isTrue);
      expect(id, 'new-gist');
      expect(client.gistId, 'new-gist');
      client.close();
    });

    test('无效 Token 会返回可读的错误', () async {
      final client = GistSyncClient(
        token: 'bad',
        gistId: 'gist-1',
        httpClient: MockClient((request) async {
          return http.Response('{"message":"Bad credentials"}', 401);
        }),
      );
      expect(
        () => client.pull(),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('Token 无效'),
          ),
        ),
      );
      client.close();
    });
  });

  group('同步控制器', () {
    test('合并远端数据、写回本地并保存 Gist id', () async {
      final storage = MemoryStorage();
      final tasks = TaskController(storage, clock: () => now);
      final stats = StatsController(storage, clock: () => now);
      final localTask = Task(
        id: 'local',
        title: '本机任务',
        createdAt: now,
        updatedAt: now,
      );
      tasks.add(localTask);

      final remoteTask = task(
        'remote',
        title: '远端任务',
        updatedAt: now.add(const Duration(minutes: 1)),
      );
      final remoteSession = session('remote-session');
      final fakeStore = _FakeStore(
        RemoteSyncData(
          gistId: 'gist-1',
          snapshot: snapshot(
            device: 'other',
            tasks: [remoteTask],
            sessions: [remoteSession],
          ),
        ),
      );

      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (token, gistId) => fakeStore,
      );
      sync.configure(token: 'token', autoSync: false);
      final ok = await sync.syncNow();

      expect(ok, isTrue);
      expect(sync.status, SyncStatus.success);
      expect(sync.gistId, 'gist-1');
      expect(tasks.taskById('remote'), isNotNull);
      expect(tasks.taskById('local'), isNotNull);
      expect(stats.sessions.map((s) => s.id), contains('remote-session'));
      expect(fakeStore.pushed, isNotNull);
      expect(fakeStore.pushed!.tasks, hasLength(greaterThanOrEqualTo(2)));
      expect(fakeStore.pushed!.deviceId, sync.deviceId);
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });

    test('远端故障时保留本地数据并给出错误', () async {
      final storage = MemoryStorage();
      final tasks = TaskController(storage, clock: () => now);
      final stats = StatsController(storage, clock: () => now);
      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (token, gistId) => _FailingStore(),
      );
      sync.configure(token: 'token', autoSync: false);
      final ok = await sync.syncNow();
      expect(ok, isFalse);
      expect(sync.status, SyncStatus.error);
      expect(sync.lastError, contains('网络'));
      expect(tasks.tasks, isNotEmpty);
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });

    test('删除任务会产生墓碑并参与下一次推送', () async {
      final storage = MemoryStorage();
      final tasks = TaskController(storage, clock: () => now);
      final stats = StatsController(storage, clock: () => now);
      final fakeStore = _FakeStore(
        const RemoteSyncData(gistId: 'gist-1', snapshot: null),
      );
      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (token, gistId) => fakeStore,
      );
      final taskId = tasks.tasks.first.id;
      tasks.remove(taskId);
      sync.configure(token: 'token', autoSync: false);
      await sync.syncNow();

      expect(fakeStore.pushed!.deletedTasks.keys, contains(taskId));
      expect(
        fakeStore.pushed!.tasks.map((task) => task.id),
        isNot(contains(taskId)),
      );
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });
  });
}

class _FakeStore implements RemoteSyncStore {
  _FakeStore(this.remote);

  final RemoteSyncData remote;
  SyncSnapshot? pushed;
  bool closed = false;

  @override
  Future<RemoteSyncData> pull() async => remote;

  @override
  Future<String> push(SyncSnapshot snapshot) async {
    pushed = snapshot;
    return 'gist-1';
  }

  @override
  void close() {
    closed = true;
  }
}

class _FailingStore implements RemoteSyncStore {
  @override
  Future<RemoteSyncData> pull() async {
    throw const SyncException('网络连接失败');
  }

  @override
  Future<String> push(SyncSnapshot snapshot) async => 'gist-1';

  @override
  void close() {}
}
