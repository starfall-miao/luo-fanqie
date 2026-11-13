import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/features/stats/models/focus_session.dart';
import 'package:luo_fanqie_app/features/stats/providers/stats_controller.dart';
import 'package:luo_fanqie_app/features/sync/models/sync_config.dart';
import 'package:luo_fanqie_app/features/sync/models/sync_snapshot.dart';
import 'package:luo_fanqie_app/features/sync/providers/sync_controller.dart';
import 'package:luo_fanqie_app/features/sync/services/remote_sync_store.dart';
import 'package:luo_fanqie_app/features/sync/services/webdav_sync_store.dart';
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

  SyncConfig webDavConfig({bool autoSync = false}) => SyncConfig(
    type: SyncServerType.webdav,
    serverUrl: 'https://dav.example.com/base/',
    username: 'user',
    password: 'pass',
    remotePath: '番茄',
    autoSync: autoSync,
  );

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

  group('WebDAV 同步客户端', () {
    test('从用户服务器读取快照，使用 Basic Auth 和远端目录', () async {
      final remoteSnapshot = snapshot(
        tasks: [task('a', title: '远端任务', updatedAt: now)],
      );
      final client = WebDavSyncStore(
        config: webDavConfig(),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://dav.example.com/base/%E7%95%AA%E8%8C%84/luo-fanqie-sync.json',
          );
          expect(
            request.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode('user:pass'))}',
          );
          return http.Response(
            remoteSnapshot.encode(),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final content = await client.download();
      expect(content, isNotNull);
      expect(SyncSnapshot.decode(content!).tasks.single.title, '远端任务');
      client.close();
    });

    test('文件不存在时返回 null，而不是报错', () async {
      final client = WebDavSyncStore(
        config: webDavConfig(),
        httpClient: MockClient((request) async => http.Response('', 404)),
      );
      expect(await client.download(), isNull);
      client.close();
    });

    test('上传时写入 JSON，认证失败给出可读错误', () async {
      var uploaded = false;
      final client = WebDavSyncStore(
        config: webDavConfig(),
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            expect(
              request.headers['Content-Type'],
              contains('application/json'),
            );
            final body = jsonDecode(utf8.decode(request.bodyBytes));
            expect(body['schemaVersion'], 1);
            uploaded = true;
            return http.Response('', 201);
          }
          return http.Response('', 401);
        }),
      );
      await client.upload(snapshot(tasks: const []).encode());
      expect(uploaded, isTrue);
      expect(
        () => client.download(),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('用户名或密码'),
          ),
        ),
      );
      client.close();
    });

    test('拒绝非 http(s) 的服务器地址', () async {
      final client = WebDavSyncStore(
        config: const SyncConfig(
          type: SyncServerType.webdav,
          serverUrl: 'dav.example.com',
        ),
        httpClient: MockClient((request) async => http.Response('', 200)),
      );
      expect(() => client.download(), throwsA(isA<SyncException>()));
      client.close();
    });
  });

  group('同步控制器', () {
    test('合并远端数据、写回文件服务器并保存同步时间', () async {
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
        remote: snapshot(
          device: 'other',
          tasks: [remoteTask],
          sessions: [remoteSession],
        ).encode(),
      );
      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (config) => fakeStore,
      );
      sync.configure(webDavConfig());
      final ok = await sync.syncNow();

      expect(ok, isTrue);
      expect(sync.status, SyncStatus.success);
      expect(tasks.taskById('remote'), isNotNull);
      expect(tasks.taskById('local'), isNotNull);
      expect(stats.sessions.map((s) => s.id), contains('remote-session'));
      expect(fakeStore.uploaded, isNotNull);
      expect(fakeStore.uploaded, contains('remote'));
      expect(sync.lastSyncAt, isNotNull);
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
        storeFactory: (config) => _FailingStore(),
      );
      sync.configure(webDavConfig());
      final ok = await sync.syncNow();
      expect(ok, isFalse);
      expect(sync.status, SyncStatus.error);
      expect(sync.lastError, contains('网络'));
      expect(tasks.tasks, isNotEmpty);
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });

    test('删除任务会产生墓碑并参与下一次写入', () async {
      final storage = MemoryStorage();
      final tasks = TaskController(storage, clock: () => now);
      final stats = StatsController(storage, clock: () => now);
      final fakeStore = _FakeStore();
      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (config) => fakeStore,
      );
      final taskId = tasks.tasks.first.id;
      tasks.remove(taskId);
      sync.configure(webDavConfig());
      await sync.syncNow();

      final uploaded = SyncSnapshot.decode(fakeStore.uploaded!);
      expect(uploaded.deletedTasks.keys, contains(taskId));
      expect(uploaded.tasks.map((task) => task.id), isNot(contains(taskId)));
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });

    test('未配置服务器时不会发起同步', () async {
      final storage = MemoryStorage();
      final tasks = TaskController(storage, clock: () => now);
      final stats = StatsController(storage, clock: () => now);
      final sync = SyncController(
        tasks: tasks,
        stats: stats,
        storage: storage,
        scheduleAutoSyncOnStart: false,
        storeFactory: (config) => _FakeStore(),
      );
      final ok = await sync.syncNow();
      expect(ok, isFalse);
      expect(sync.lastError, contains('设置'));
      sync.dispose();
      tasks.dispose();
      stats.dispose();
    });
  });
}

class _FakeStore implements RemoteSyncStore {
  _FakeStore({this.remote});

  final String? remote;
  String? uploaded;
  bool closed = false;

  @override
  Future<String?> download() async => remote;

  @override
  Future<void> upload(String content) async {
    uploaded = content;
  }

  @override
  Future<void> test() async {}

  @override
  void close() {
    closed = true;
  }
}

class _FailingStore implements RemoteSyncStore {
  @override
  Future<String?> download() async {
    throw const SyncException('网络连接失败');
  }

  @override
  Future<void> upload(String content) async {}

  @override
  Future<void> test() async {}

  @override
  void close() {}
}
