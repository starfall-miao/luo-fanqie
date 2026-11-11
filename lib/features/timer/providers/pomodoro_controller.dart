// 构造参数是对外 API，字段保持私有以免外部直接改写状态。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/notifications/timer_notification_service.dart';
import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/models/focus_session.dart';
import '../../stats/providers/stats_controller.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_controller.dart';
import '../models/pomodoro_phase.dart';

class FocusCompletion {
  const FocusCompletion({
    required this.session,
    required this.phaseMinutes,
    this.task,
  });

  final FocusSession session;
  final int phaseMinutes;
  final Task? task;
}

/// 番茄钟状态机。
///
/// 计时以「结束时间」为准而不是逐秒累加，因此即使 App 被系统冻结，
/// 回到前台时也会立刻校准。活动中的计时快照会写入本地，冷启动后可以恢复。
class PomodoroController extends ChangeNotifier {
  PomodoroController({
    required TaskController tasks,
    required StatsController stats,
    required SettingsController settings,
    required KeyValueStorage storage,
    TimerNotificationService? notifications,
    DateTime Function()? clock,
  }) : _tasks = tasks,
       _stats = stats,
       _settings = settings,
       _storage = storage,
       _notifications = notifications ?? const NoopTimerNotificationService(),
       _now = clock ?? DateTime.now {
    _tasks.addListener(_handleTasksChanged);
    _settings.addListener(_handleSettingsChanged);
    _restore();
  }

  static const _storageKey = 'luo_fanqie.timer.v1';
  static const _tickInterval = Duration(milliseconds: 200);

  final TaskController _tasks;
  final StatsController _stats;
  final SettingsController _settings;
  final KeyValueStorage _storage;
  final TimerNotificationService _notifications;
  final DateTime Function() _now;
  bool _permissionRequested = false;

  final ValueNotifier<FocusCompletion?> justCompleted = ValueNotifier(null);

  PomodoroPhase _phase = PomodoroPhase.focus;
  PomodoroStatus _status = PomodoroStatus.idle;
  int _totalMillis = 25 * 60 * 1000;
  int _remainingMillis = 25 * 60 * 1000;
  int _completedInCycle = 0;
  String? _selectedTaskId;
  DateTime? _endAt;
  DateTime? _phaseStartedAt;
  Timer? _ticker;

  PomodoroPhase get phase => _phase;

  PomodoroStatus get status => _status;

  bool get isRunning => _status == PomodoroStatus.running;

  bool get isPaused => _status == PomodoroStatus.paused;

  bool get isIdle => _status == PomodoroStatus.idle;

  bool get isFocus => _phase == PomodoroPhase.focus;

  int get totalMillis => _totalMillis;

  int get remainingMillis => math.max(0, _remainingMillis);

  double get progress {
    if (_totalMillis <= 0) return 1;
    return (1 - remainingMillis / _totalMillis).clamp(0.0, 1.0);
  }

  String get remainingLabel => timerLabel(remainingMillis);

  int get completedInCycle => _completedInCycle;

  int get roundsPerLongBreak => _settings.settings.roundsPerLongBreak;

  int get roundNumber =>
      math.min(_completedInCycle + 1, _settings.settings.roundsPerLongBreak);

  String? get selectedTaskId => _selectedTaskId;

  Task? get selectedTask => _tasks.taskById(_selectedTaskId);

  List<Task> get pickableTasks => _tasks.pending;

  int get todayMinutes => _stats.todayMinutes;

  int get todaySessions => _stats.todaySessions;

  int durationFor(PomodoroPhase phase) {
    final settings = _settings.settings;
    final minutes = switch (phase) {
      PomodoroPhase.focus => settings.focusMinutes,
      PomodoroPhase.shortBreak => settings.shortBreakMinutes,
      PomodoroPhase.longBreak => settings.longBreakMinutes,
    };
    return minutes * 60 * 1000;
  }

  void toggle() {
    if (isRunning) {
      pause();
    } else {
      start();
    }
  }

  void start() {
    if (isRunning || remainingMillis <= 0) return;
    if (isIdle) {
      _totalMillis = durationFor(_phase);
      _remainingMillis = _totalMillis;
    }
    _phaseStartedAt ??= _now();
    _status = PomodoroStatus.running;
    _endAt = _now().add(Duration(milliseconds: remainingMillis));
    _startTicker();
    _persist();
    notifyListeners();

    if (_settings.settings.notificationsEnabled) {
      _requestNotificationPermissionOnce();
    }
    _scheduleNotification();
  }

  void pause() {
    if (!isRunning) return;
    if (_endAt != null) {
      _remainingMillis = math.max(0, _endAt!.difference(_now()).inMilliseconds);
    }
    _endAt = null;
    _status = PomodoroStatus.paused;
    _ticker?.cancel();
    _ticker = null;
    _cancelNotification();
    _persist();
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = PomodoroStatus.idle;
    _endAt = null;
    _phaseStartedAt = null;
    _totalMillis = durationFor(_phase);
    _remainingMillis = _totalMillis;
    _cancelNotification();
    _persist();
    notifyListeners();
  }

  /// 跳过当前阶段（不记录番茄），回到下一阶段的待开始状态。
  void skip() {
    _ticker?.cancel();
    _ticker = null;
    _endAt = null;
    _phaseStartedAt = null;
    if (_phase == PomodoroPhase.focus) {
      _phase = PomodoroPhase.shortBreak;
    } else {
      if (_phase == PomodoroPhase.longBreak) _completedInCycle = 0;
      _phase = PomodoroPhase.focus;
    }
    _status = PomodoroStatus.idle;
    _totalMillis = durationFor(_phase);
    _remainingMillis = _totalMillis;
    _cancelNotification();
    _persist();
    notifyListeners();
  }

  /// 仅允许在暂停或待开始时切换阶段。
  bool switchPhase(PomodoroPhase phase) {
    if (isRunning) return false;
    if (_phase == phase) return true;
    _phase = phase;
    _status = PomodoroStatus.idle;
    _endAt = null;
    _phaseStartedAt = null;
    _totalMillis = durationFor(phase);
    _remainingMillis = _totalMillis;
    _cancelNotification();
    _persist();
    notifyListeners();
    return true;
  }

  /// 专注进行中不允许切换任务，避免一次专注被拆分到多个任务上。
  bool selectTask(String? taskId) {
    if (isRunning) return false;
    if (taskId != null && _tasks.taskById(taskId) == null) return false;
    _selectedTaskId = taskId;
    _persist();
    notifyListeners();
    return true;
  }

  /// App 回到前台时调用，把被系统暂停的计时拉回正确状态。
  void syncTime() {
    if (isRunning) _onTick();
  }

  FocusCompletion? consumeCompletion() {
    final completion = justCompleted.value;
    if (completion != null) justCompleted.value = null;
    return completion;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  void _onTick() {
    if (!isRunning || _endAt == null) return;
    final remaining = _endAt!.difference(_now()).inMilliseconds;
    if (remaining <= 0) {
      _remainingMillis = 0;
      _finishPhase();
      return;
    }
    _remainingMillis = remaining;
    notifyListeners();
  }

  void _finishPhase({DateTime? endedAt, bool silent = false}) {
    _ticker?.cancel();
    _ticker = null;
    // 阶段自然结束时保留已经弹出的系统通知，让用户切回桌面也能看到。
    // 暂停、重置、跳过等主动取消的操作才会移除通知。
    final finishedPhase = _phase;
    final finishedAt = endedAt ?? _now();
    final startedAt =
        _phaseStartedAt ??
        finishedAt.subtract(Duration(milliseconds: _totalMillis));
    final wasFocus = finishedPhase == PomodoroPhase.focus;
    final task = selectedTask;

    FocusSession? session;
    if (wasFocus) {
      final minutes = math.max(1, (_totalMillis / 60000).round());
      session = FocusSession(
        id: 'focus-${finishedAt.microsecondsSinceEpoch}-${_selectedTaskId ?? 'free'}',
        taskId: _selectedTaskId,
        taskTitle: task?.title ?? '自由专注',
        startedAt: startedAt,
        endedAt: finishedAt,
        minutes: minutes,
      );
      final recorded = _stats.record(session);
      if (recorded && task != null) _tasks.incrementPomodoro(task.id);
      _completedInCycle += 1;
      if (!silent) _feedback();
      justCompleted.value = FocusCompletion(
        session: session,
        phaseMinutes: session.minutes,
        task: task,
      );
    }

    _endAt = null;
    _phaseStartedAt = null;
    _status = PomodoroStatus.idle;

    if (wasFocus) {
      _phase = _completedInCycle >= _settings.settings.roundsPerLongBreak
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
    } else {
      if (finishedPhase == PomodoroPhase.longBreak) _completedInCycle = 0;
      _phase = PomodoroPhase.focus;
    }

    _totalMillis = durationFor(_phase);
    _remainingMillis = _totalMillis;
    _persist();
    notifyListeners();

    final shouldAutoStart = wasFocus
        ? _settings.settings.autoStartBreak
        : _settings.settings.autoStartFocus;
    if (shouldAutoStart) start();
  }

  void _feedback() {
    final settings = _settings.settings;
    if (settings.hapticsEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
    if (settings.soundEnabled) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  void _handleTasksChanged() {
    if (_selectedTaskId == null) return;
    if (_tasks.taskById(_selectedTaskId) != null) return;
    _selectedTaskId = null;
    _persist();
    notifyListeners();
  }

  void _handleSettingsChanged() {
    if (!_settings.settings.notificationsEnabled) {
      _cancelNotification();
    } else if (isRunning) {
      _requestNotificationPermissionOnce();
      _scheduleNotification();
    }
    if (!isIdle) return;
    final total = durationFor(_phase);
    if (total == _totalMillis) return;
    _totalMillis = total;
    _remainingMillis = total;
    _persist();
    notifyListeners();
  }

  void _requestNotificationPermissionOnce() {
    if (_permissionRequested) return;
    _permissionRequested = true;
    unawaited(_notifications.requestPermission());
  }

  void _scheduleNotification() {
    if (!_settings.settings.notificationsEnabled ||
        !isRunning ||
        _endAt == null) {
      return;
    }
    final minutes = math.max(1, (_totalMillis / 60000).round());
    final taskTitle = selectedTask?.title;
    final isFocus = _phase == PomodoroPhase.focus;
    unawaited(
      _notifications.schedule(
        fireAt: _endAt!,
        title: isFocus ? '番茄落袋 · $minutes 分钟' : '休息结束',
        body: isFocus ? (taskTitle ?? '自由专注') : '回来，开始下一颗番茄吧。',
      ),
    );
  }

  void _cancelNotification() {
    unawaited(_notifications.cancel());
  }

  void _persist() {
    final snapshot = <String, dynamic>{
      'version': 1,
      'phase': _phase.name,
      'status': _status.name,
      'totalMillis': _totalMillis,
      'remainingMillis': _remainingMillis,
      'endAt': _endAt?.toIso8601String(),
      'phaseStartedAt': _phaseStartedAt?.toIso8601String(),
      'completedInCycle': _completedInCycle,
      'selectedTaskId': _selectedTaskId,
    };
    unawaited(_storage.write(_storageKey, jsonEncode(snapshot)));
  }

  void _restore() {
    final raw = _storage.read(_storageKey);
    if (raw == null) {
      _totalMillis = durationFor(_phase);
      _remainingMillis = _totalMillis;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      _phase = PomodoroPhase.values.firstWhere(
        (phase) => phase.name == json['phase'],
        orElse: () => PomodoroPhase.focus,
      );
      _status = PomodoroStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => PomodoroStatus.idle,
      );
      _totalMillis = math.max(
        1,
        (json['totalMillis'] as num?)?.toInt() ?? durationFor(_phase),
      );
      _remainingMillis =
          ((json['remainingMillis'] as num?)?.toInt() ?? _totalMillis).clamp(
            0,
            _totalMillis,
          );
      _completedInCycle = math.max(
        0,
        (json['completedInCycle'] as num?)?.toInt() ?? 0,
      );
      final selectedId = json['selectedTaskId'] as String?;
      _selectedTaskId = _tasks.taskById(selectedId) == null ? null : selectedId;
      _phaseStartedAt = DateTime.tryParse(
        json['phaseStartedAt'] as String? ?? '',
      );
      final endAt = DateTime.tryParse(json['endAt'] as String? ?? '');

      if (_status == PomodoroStatus.running && endAt != null) {
        final remaining = endAt.difference(_now()).inMilliseconds;
        if (remaining > 0) {
          _endAt = endAt;
          _remainingMillis = remaining.clamp(0, _totalMillis);
          _startTicker();
          _scheduleNotification();
        } else {
          _status = PomodoroStatus.running;
          _endAt = endAt;
          _remainingMillis = 0;
          _finishPhase(endedAt: endAt, silent: true);
        }
      } else if (_status == PomodoroStatus.running) {
        _status = PomodoroStatus.paused;
      }

      if (isIdle) {
        _totalMillis = durationFor(_phase);
        _remainingMillis = _totalMillis;
      }
      if (!isRunning) _cancelNotification();
    } catch (_) {
      _totalMillis = durationFor(_phase);
      _remainingMillis = _totalMillis;
      _cancelNotification();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tasks.removeListener(_handleTasksChanged);
    _settings.removeListener(_handleSettingsChanged);
    justCompleted.dispose();
    super.dispose();
  }
}
