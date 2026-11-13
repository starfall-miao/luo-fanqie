import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:luo_fanqie_app/core/notifications/timer_notification_service.dart';
import 'package:luo_fanqie_app/core/utils/date_utils.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/features/settings/models/app_settings.dart';
import 'package:luo_fanqie_app/features/settings/providers/settings_controller.dart';
import 'package:luo_fanqie_app/features/stats/models/focus_session.dart';
import 'package:luo_fanqie_app/features/stats/models/interruption_event.dart';
import 'package:luo_fanqie_app/features/stats/providers/stats_controller.dart';
import 'package:luo_fanqie_app/features/tasks/models/task.dart';
import 'package:luo_fanqie_app/features/tasks/providers/task_controller.dart';
import 'package:luo_fanqie_app/features/timer/models/pomodoro_phase.dart';
import 'package:luo_fanqie_app/features/timer/providers/pomodoro_controller.dart';

void main() {
  final fixedNow = DateTime(2026, 11, 8, 18, 30);

  group('任务模型与控制器', () {
    test('任务 JSON 往返保留字段', () {
      final task = Task(
        id: 'task-1',
        title: '写一篇文章',
        notes: '先列提纲',
        estimatedPomodoros: 3,
        completedPomodoros: 1,
        priority: TaskPriority.high,
        tag: '我的自定义标签',
        kind: TaskKind.goal,
        focusMinutes: 30,
        targetAmount: 2.5,
        targetUnit: TaskUnit.hours,
        habitSchedule: HabitSchedule.weeklyQuota,
        weekdays: const [1, 3, 5],
        progressAmount: 1.5,
        dueDate: DateTime(2026, 11, 9),
        createdAt: fixedNow,
      );
      final restored = Task.fromJson(task.toJson());
      expect(restored.title, '写一篇文章');
      expect(restored.notes, '先列提纲');
      expect(restored.estimatedPomodoros, 3);
      expect(restored.priority, TaskPriority.high);
      expect(restored.tag, '我的自定义标签');
      expect(restored.kind, TaskKind.goal);
      expect(restored.focusMinutes, 30);
      expect(restored.targetAmount, 2.5);
      expect(restored.targetUnit, TaskUnit.hours);
      expect(restored.weekdays, [1, 3, 5]);
      expect(restored.progressAmount, 1.5);
      expect(restored.dueDate, DateTime(2026, 11, 9));
      expect(restored.done, isFalse);
    });

    test('首次启动种下示例任务，之后不会重复', () {
      final storage = MemoryStorage();
      final first = TaskController(storage, clock: () => fixedNow);
      expect(first.tasks, hasLength(3));
      final second = TaskController(storage, clock: () => fixedNow);
      expect(second.tasks, hasLength(3));
      expect(
        second.tasks.map((task) => task.id),
        containsAll(first.tasks.map((task) => task.id)),
      );
    });

    test('新增、完成、删除与撤销', () {
      final storage = MemoryStorage();
      final controller = TaskController(storage, clock: () => fixedNow);
      final task = Task(
        id: 'task-new',
        title: '跑五公里',
        estimatedPomodoros: 1,
        createdAt: fixedNow,
      );
      controller.add(task);
      expect(controller.pendingCount, 4);
      expect(controller.taskById('task-new')!.title, '跑五公里');

      controller.toggleDone('task-new');
      expect(controller.taskById('task-new')!.done, isTrue);
      expect(controller.completedTodayCount, 1);
      expect(controller.completed, hasLength(1));

      final removed = controller.remove('task-new');
      expect(removed, isNotNull);
      expect(controller.taskById('task-new'), isNull);
      controller.insert(removed!);
      expect(controller.taskById('task-new'), isNotNull);

      controller.incrementPomodoro('task-new');
      expect(controller.taskById('task-new')!.completedPomodoros, 1);
    });

    test('目标按专注分钟累计，习惯按周期重置', () {
      final storage = MemoryStorage();
      final controller = TaskController(storage, clock: () => fixedNow);
      final goal = Task(
        id: 'goal',
        title: '阅读 4 小时',
        createdAt: fixedNow,
        kind: TaskKind.goal,
        focusMinutes: 30,
        targetAmount: 4,
        targetUnit: TaskUnit.hours,
      );
      final habit = Task(
        id: 'habit',
        title: '每天阅读 30 分钟',
        createdAt: fixedNow,
        kind: TaskKind.habit,
        targetAmount: 30,
        targetUnit: TaskUnit.minutes,
        progressPeriodKey: 'day-${dateKey(fixedNow)}',
        progressAmount: 20,
      );
      controller.add(goal);
      controller.add(habit);

      controller.recordFocus('goal', minutes: 30, at: fixedNow);
      expect(controller.taskById('goal')!.completedPomodoros, 1);
      expect(controller.taskById('goal')!.progressAmount, 0.5);

      controller.recordFocus('habit', minutes: 25, at: fixedNow);
      expect(controller.taskById('habit')!.progressAmount, 45);

      controller.recordFocus('habit', minutes: 25, at: addDays(fixedNow, 1));
      expect(controller.taskById('habit')!.progressAmount, 25);

      final custom = Task(
        id: 'custom',
        title: '跨设备同步',
        createdAt: fixedNow,
        tag: '我的标签',
        focusMinutes: 20,
      );
      controller.add(custom);
      expect(controller.taskById('custom')!.tag, '我的标签');
    });

    test('每个待办可以覆盖单次专注时长', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        final task = harness.tasks.pending.first.copyWith(focusMinutes: 40);
        harness.tasks.update(task);
        harness.timer.selectTask(task.id);
        harness.timer.start(focusMinutes: task.focusMinutes);
        expect(harness.timer.totalMillis, 40 * 60 * 1000);
        async.elapse(const Duration(minutes: 40, seconds: 1));
        expect(harness.stats.todayMinutes, 40);
        harness.dispose();
      });
    });

    test('排序把未完成和高优先级放在前面', () {
      final storage = MemoryStorage();
      final controller = TaskController(storage, clock: () => fixedNow);
      final sorted = controller.sorted;
      expect(sorted.first.done, isFalse);
      final priorities = sorted
          .where((task) => !task.done)
          .map((task) => task.priority.weight)
          .toList();
      expect(
        priorities,
        orderedEquals([...priorities]..sort((a, b) => b.compareTo(a))),
      );
    });
  });

  group('设置', () {
    test('默认值、夹取范围与持久化', () {
      final storage = MemoryStorage();
      final controller = SettingsController(storage);
      expect(controller.settings.focusMinutes, 25);
      controller.setFocusMinutes(999);
      expect(controller.settings.focusMinutes, 180);
      controller.setFocusMinutes(0);
      expect(controller.settings.focusMinutes, 1);
      controller.setThemeMode(AppThemeMode.dark);
      final restored = SettingsController(storage);
      expect(restored.settings.themeMode, AppThemeMode.dark);
      expect(restored.themeMode, ThemeMode.dark);
    });

    test('白名单与学霸拆分选项可持久化', () {
      final storage = MemoryStorage();
      final controller = SettingsController(storage);
      controller.setWhitelistPackages(['com.example.dictionary']);
      controller.setStrictOverlay(false);
      controller.setStrictLockTask(true);
      controller.setStrictDnd(true);
      final restored = SettingsController(storage);
      expect(restored.settings.whitelistPackages, ['com.example.dictionary']);
      expect(restored.settings.strictOverlay, isFalse);
      expect(restored.settings.strictLockTask, isTrue);
      expect(restored.settings.strictDnd, isTrue);
    });

    test('损坏的设置数据回退默认值', () {
      final storage = MemoryStorage({'luo_fanqie.settings.v1': '{bad json'});
      final controller = SettingsController(storage);
      expect(controller.settings.focusMinutes, 25);
    });
  });

  group('专注统计', () {
    test('按天聚合、去重与连续天数', () {
      final storage = MemoryStorage();
      final stats = StatsController(storage, clock: () => fixedNow);
      FocusSession session(String id, DateTime endedAt, {int minutes = 25}) =>
          FocusSession(
            id: id,
            startedAt: endedAt.subtract(Duration(minutes: minutes)),
            endedAt: endedAt,
            minutes: minutes,
          );

      stats.record(session('a', fixedNow));
      stats.record(session('a', fixedNow));
      stats.record(session('b', fixedNow, minutes: 25));
      stats.record(session('c', fixedNow.subtract(const Duration(days: 1))));
      expect(stats.todaySessions, 2);
      expect(stats.todayMinutes, 50);
      expect(stats.streak, 2);
      expect(stats.totalSessions, 3);
      expect(stats.totalMinutes, 75);

      final days = stats.lastNDays(3);
      expect(days, hasLength(3));
      expect(days.last.minutes, 50);
      expect(days[1].minutes, 25);
      expect(days.first.minutes, 0);

      final heatmap = stats.heatmap(weeks: 2);
      expect(heatmap, hasLength(14));
      expect(heatmap.last.date.weekday, DateTime.sunday);
    });

    test('记录打断原因并随清空记录一起清除', () {
      final storage = MemoryStorage();
      final stats = StatsController(storage, clock: () => fixedNow);
      expect(
        stats.recordInterruption(
          InterruptionEvent(
            id: 'interruption-1',
            at: fixedNow,
            reason: '分心走神',
            elapsedMinutes: 8,
          ),
        ),
        isTrue,
      );
      expect(stats.interruptions.single.reason, '分心走神');
      expect(
        stats.interruptionsBetween(
          fixedNow.subtract(const Duration(days: 1)),
          fixedNow.add(const Duration(days: 1)),
        ),
        hasLength(1),
      );
      stats.clearAll();
      expect(stats.interruptions, isEmpty);
    });

    test('今天没有记录时，连续天数延续到昨天', () {
      final stats = StatsController(MemoryStorage(), clock: () => fixedNow);
      stats.record(
        FocusSession(
          id: 'yesterday',
          startedAt: fixedNow.subtract(const Duration(days: 1, hours: 1)),
          endedAt: fixedNow.subtract(const Duration(days: 1)),
          minutes: 25,
        ),
      );
      expect(stats.streak, 1);
      expect(stats.todayMinutes, 0);
    });
  });

  group('番茄钟状态机', () {
    test('完整专注会记录统计、增加任务番茄并进入休息', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        final task = harness.tasks.pending.first;
        harness.timer.selectTask(task.id);
        harness.timer.start();
        expect(harness.timer.isRunning, isTrue);

        async.elapse(const Duration(minutes: 25, seconds: 1));

        expect(harness.stats.todaySessions, 1);
        expect(harness.stats.todayMinutes, 25);
        expect(harness.tasks.taskById(task.id)!.completedPomodoros, 1);
        expect(harness.timer.phase, PomodoroPhase.shortBreak);
        expect(harness.timer.isIdle, isTrue);
        expect(harness.timer.completedInCycle, 1);
        expect(harness.timer.justCompleted.value, isNotNull);
        harness.dispose();
      });
    });

    test('暂停与继续保持正确的剩余时间', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        async.elapse(const Duration(minutes: 10));
        harness.timer.pause();
        final remaining = harness.timer.remainingMillis;
        expect(remaining, lessThanOrEqualTo(15 * 60 * 1000));
        expect(harness.timer.isPaused, isTrue);

        async.elapse(const Duration(minutes: 5));
        expect(harness.timer.remainingMillis, remaining);
        harness.timer.start();
        async.elapse(const Duration(minutes: 15, seconds: 1));
        expect(harness.stats.todaySessions, 1);
        harness.dispose();
      });
    });

    test('跳过阶段不记录番茄', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        async.elapse(const Duration(minutes: 2));
        harness.timer.skip();
        expect(harness.stats.totalSessions, 0);
        expect(harness.timer.phase, PomodoroPhase.shortBreak);
        expect(harness.timer.isIdle, isTrue);
        harness.dispose();
      });
    });

    test('每四颗番茄进入长休息，长休息后重新计数', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        for (var i = 0; i < 4; i += 1) {
          harness.timer.start();
          async.elapse(const Duration(minutes: 25, seconds: 1));
          expect(harness.timer.completedInCycle, i + 1);
          if (i < 3) {
            expect(harness.timer.phase, PomodoroPhase.shortBreak);
            harness.timer.skip();
          }
        }
        expect(harness.timer.phase, PomodoroPhase.longBreak);
        harness.timer.skip();
        expect(harness.timer.phase, PomodoroPhase.focus);
        expect(harness.timer.completedInCycle, 0);
        expect(harness.stats.todaySessions, 4);
        harness.dispose();
      });
    });

    test('自动开始休息', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(
          clock: () => base.add(async.elapsed),
          autoBreak: true,
        );
        harness.timer.start();
        async.elapse(const Duration(minutes: 25, seconds: 1));
        expect(harness.timer.phase, PomodoroPhase.shortBreak);
        expect(harness.timer.isRunning, isTrue);
        harness.timer.pause();
        harness.dispose();
      });
    });

    test('冷启动恢复进行中的计时', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        harness.disposeTimer();

        final restored = PomodoroController(
          tasks: harness.tasks,
          stats: harness.stats,
          settings: harness.settings,
          storage: harness.storage,
          clock: () => base.add(async.elapsed),
        );
        expect(restored.isRunning, isTrue);
        expect(restored.remainingMillis, lessThanOrEqualTo(25 * 60 * 1000));
        restored.dispose();
        harness.dispose();
      });
    });

    test('冷启动时发现计时已结束，补记一颗番茄', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        harness.disposeTimer();
        async.elapse(const Duration(minutes: 40));

        final restored = PomodoroController(
          tasks: harness.tasks,
          stats: harness.stats,
          settings: harness.settings,
          storage: harness.storage,
          clock: () => base.add(async.elapsed),
        );
        expect(harness.stats.todaySessions, 1);
        expect(restored.phase, PomodoroPhase.shortBreak);
        expect(restored.isIdle, isTrue);
        restored.dispose();
        harness.dispose();
      });
    });

    test('设置变更在待开始时同步到计时器', () {
      final harness = _Harness(clock: () => fixedNow);
      expect(harness.timer.remainingMillis, 25 * 60 * 1000);
      harness.settings.setFocusMinutes(45);
      expect(harness.timer.remainingMillis, 45 * 60 * 1000);
      harness.dispose();
    });

    test('开始专注会安排通知，暂停会取消通知', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        expect(harness.notifications.scheduled, hasLength(1));
        expect(harness.notifications.scheduled.first.title, contains('番茄落袋'));
        expect(
          harness.notifications.scheduled.first.fireAt,
          base.add(const Duration(minutes: 25)),
        );

        harness.timer.pause();
        expect(harness.notifications.cancelCount, greaterThanOrEqualTo(1));
        expect(harness.notifications.scheduled, hasLength(1));

        harness.timer.start();
        expect(harness.notifications.scheduled, hasLength(2));
        harness.dispose();
      });
    });

    test('关闭系统通知会取消待发送提醒', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(clock: () => base.add(async.elapsed));
        harness.timer.start();
        final before = harness.notifications.cancelCount;
        harness.settings.setNotificationsEnabled(false);
        expect(harness.notifications.cancelCount, greaterThan(before));
        harness.timer.pause();
        harness.dispose();
      });
    });

    test('自动开始休息时会为休息阶段重新安排通知', () {
      fakeAsync((async) {
        final base = DateTime(2026, 11, 8, 9);
        final harness = _Harness(
          clock: () => base.add(async.elapsed),
          autoBreak: true,
        );
        harness.timer.start();
        async.elapse(const Duration(minutes: 25, seconds: 1));
        expect(harness.timer.phase, PomodoroPhase.shortBreak);
        expect(harness.notifications.scheduled, hasLength(2));
        expect(harness.notifications.scheduled.last.title, '休息结束');
        harness.timer.pause();
        harness.dispose();
      });
    });
  });
}

class _Harness {
  _Harness({required this.clock, this.autoBreak = false}) {
    storage = MemoryStorage();
    settings = SettingsController(storage);
    settings.setSoundEnabled(false);
    settings.setHapticsEnabled(false);
    settings.setAutoStartBreak(autoBreak);
    settings.setAutoStartFocus(false);
    tasks = TaskController(storage, clock: clock);
    stats = StatsController(storage, clock: clock);
    notifications = _FakeTimerNotifications();
    timer = PomodoroController(
      tasks: tasks,
      stats: stats,
      settings: settings,
      storage: storage,
      notifications: notifications,
      clock: clock,
    );
  }

  final DateTime Function() clock;
  final bool autoBreak;

  late final MemoryStorage storage;
  late final SettingsController settings;
  late final TaskController tasks;
  late final StatsController stats;
  late final _FakeTimerNotifications notifications;
  late final PomodoroController timer;

  bool _timerDisposed = false;

  void disposeTimer() {
    if (_timerDisposed) return;
    _timerDisposed = true;
    timer.dispose();
  }

  void dispose() {
    disposeTimer();
    settings.dispose();
    tasks.dispose();
    stats.dispose();
  }
}

class _ScheduledNotification {
  const _ScheduledNotification({
    required this.fireAt,
    required this.title,
    required this.body,
  });

  final DateTime fireAt;
  final String title;
  final String body;
}

class _FakeTimerNotifications implements TimerNotificationService {
  final List<_ScheduledNotification> scheduled = [];
  int cancelCount = 0;
  int permissionRequests = 0;

  @override
  Future<void> requestPermission() async {
    permissionRequests += 1;
  }

  @override
  Future<void> schedule({
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {
    scheduled.add(
      _ScheduledNotification(fireAt: fireAt, title: title, body: body),
    );
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
  }
}
