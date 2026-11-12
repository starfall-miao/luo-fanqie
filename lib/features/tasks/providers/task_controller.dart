import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_utils.dart';
import '../models/task.dart';

class TaskController extends ChangeNotifier {
  TaskController(this._storage, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final raw = _storage.read(_storageKey);
    if (raw == null) {
      _tasks = _seedTasks(_now());
      unawaited(_persist());
    } else {
      _tasks = _decode(raw);
    }
    _deleted = _decodeDeleted(_storage.read(_deletedKey));
    _pruneTombstones();
  }

  static const _storageKey = 'luo_fanqie.tasks.v1';
  static const _deletedKey = 'luo_fanqie.tasks.deleted.v1';
  static const _tombstoneLifetime = Duration(days: 90);

  final KeyValueStorage _storage;
  final DateTime Function() _now;
  List<Task> _tasks = <Task>[];
  Map<String, DateTime> _deleted = <String, DateTime>{};

  List<Task> get tasks => List<Task>.unmodifiable(_tasks);

  List<Task> get sorted => [..._tasks]..sort(Task.compareForDisplay);

  List<Task> get pending =>
      sorted.where((task) => !task.done).toList(growable: false);

  List<Task> get completed =>
      sorted.where((task) => task.done).toList(growable: false);

  int get pendingCount => _tasks.where((task) => !task.done).length;

  int get completedTodayCount {
    final today = startOfDay(_now());
    return _tasks.where((task) {
      final completedAt = task.completedAt;
      return task.done && completedAt != null && isSameDay(completedAt, today);
    }).length;
  }

  int get pendingEstimatedPomodoros => _tasks
      .where((task) => !task.done)
      .fold<int>(0, (sum, task) => sum + task.estimatedPomodoros);

  Task? taskById(String? id) {
    if (id == null) return null;
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Map<String, DateTime> get deletedTasks =>
      Map<String, DateTime>.unmodifiable(_deleted);

  void add(Task task) {
    final now = _now();
    final next = task.copyWith(updatedAt: now);
    _deleted.remove(task.id);
    _tasks = [next, ..._tasks];
    _commit();
  }

  void update(Task task) {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    _deleted.remove(task.id);
    _tasks = [..._tasks]..[index] = task.copyWith(updatedAt: _now());
    _commit();
  }

  Task? remove(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return null;
    final removed = _tasks[index];
    _deleted[id] = _now();
    _tasks = [..._tasks]..removeAt(index);
    _commit();
    return removed;
  }

  void insert(Task task, {int index = 0}) {
    final safeIndex = index.clamp(0, _tasks.length);
    _deleted.remove(task.id);
    _tasks = [..._tasks]..insert(safeIndex, task.copyWith(updatedAt: _now()));
    _commit();
  }

  /// 同步合并在不触发逐条更新时间的情况下写回完整结果。
  void applyMerged({
    required List<Task> tasks,
    required Map<String, DateTime> deletedTasks,
  }) {
    final now = _now();
    _tasks = tasks;
    _deleted = Map<String, DateTime>.from(deletedTasks);
    // 删除发生得比最后修改更晚才算删除；否则任务应恢复显示。
    for (final task in _tasks) {
      final deletedAt = _deleted[task.id];
      if (deletedAt != null && !deletedAt.isAfter(task.lastModified)) {
        _deleted.remove(task.id);
      }
    }
    _deleted.removeWhere(
      (id, deletedAt) => now.difference(deletedAt) > _tombstoneLifetime,
    );
    notifyListeners();
    unawaited(_persist());
  }

  void toggleDone(String id) {
    final task = taskById(id);
    if (task == null) return;
    final now = _now();
    final next = task.done
        ? task.copyWith(done: false, clearCompletedAt: true)
        : task.copyWith(done: true, completedAt: now);
    update(next);
  }

  /// 记录一次完成的专注：普通任务累计番茄数，目标/习惯累计进度。
  void recordFocus(String id, {required int minutes, DateTime? at}) {
    final task = taskById(id);
    if (task == null) return;
    final now = at ?? _now();
    final periodKey = task.periodKeyFor(now);
    var progress = task.effectiveProgress(now);
    if (task.isHabit && task.progressPeriodKey != periodKey) {
      progress = 0;
    }
    if (task.hasTarget) {
      progress += task.amountForFocus(minutes);
    }
    update(
      task.copyWith(
        completedPomodoros: task.completedPomodoros + 1,
        progressAmount: task.hasTarget ? progress : task.progressAmount,
        progressPeriodKey: task.isHabit ? periodKey : task.progressPeriodKey,
      ),
    );
  }

  void incrementPomodoro(String id, {int? minutes}) {
    final task = taskById(id);
    if (task == null) return;
    recordFocus(id, minutes: minutes ?? task.focusMinutes);
  }

  int clearCompleted() {
    final removed = _tasks.where((task) => task.done).toList();
    if (removed.isEmpty) return 0;
    final now = _now();
    for (final task in removed) {
      _deleted[task.id] = now;
    }
    _tasks = _tasks.where((task) => !task.done).toList();
    _commit();
    return removed.length;
  }

  void clearAll() {
    final now = _now();
    for (final task in _tasks) {
      _deleted[task.id] = now;
    }
    _tasks = <Task>[];
    _commit();
  }

  void restoreSeedTasks() {
    _deleted = <String, DateTime>{};
    _tasks = _seedTasks(_now());
    _commit();
  }

  void _commit() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await Future.wait([
      _storage.write(
        _storageKey,
        jsonEncode(_tasks.map((t) => t.toJson()).toList()),
      ),
      _storage.write(
        _deletedKey,
        jsonEncode(
          _deleted.map((id, at) => MapEntry(id, at.toIso8601String())),
        ),
      ),
    ]);
  }

  Map<String, DateTime> _decodeDeleted(String? raw) {
    if (raw == null) return <String, DateTime>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, DateTime>{};
      final result = <String, DateTime>{};
      decoded.forEach((key, value) {
        if (key is String && value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) result[key] = parsed;
        }
      });
      return result;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  void _pruneTombstones() {
    final now = _now();
    _deleted.removeWhere(
      (id, deletedAt) => now.difference(deletedAt) > _tombstoneLifetime,
    );
  }

  List<Task> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Task>[];
      return decoded
          .whereType<Map>()
          .map((map) => Task.fromJson(Map<String, dynamic>.from(map)))
          .where((task) => task.title.isNotEmpty)
          .toList();
    } catch (_) {
      return <Task>[];
    }
  }

  List<Task> _seedTasks(DateTime now) {
    final today = startOfDay(now);
    return [
      Task(
        id: newId('task'),
        title: '完成落·番茄的首页设计',
        notes: '把它拆小一点，然后专心完成第一颗番茄。',
        estimatedPomodoros: 4,
        priority: TaskPriority.high,
        tag: '工作',
        dueDate: today,
        focusMinutes: 25,
        createdAt: now,
      ),
      Task(
        id: newId('task'),
        title: '本周阅读 4 小时',
        notes: '读完手头这本书，把喜欢的句子记下来。',
        kind: TaskKind.goal,
        focusMinutes: 30,
        targetAmount: 4,
        targetUnit: TaskUnit.hours,
        priority: TaskPriority.medium,
        tag: '阅读',
        dueDate: addDays(today, 7),
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      Task(
        id: newId('task'),
        title: '每天阅读 30 分钟',
        notes: '给每天留一小段安静的阅读时间。',
        kind: TaskKind.habit,
        focusMinutes: 25,
        targetAmount: 30,
        targetUnit: TaskUnit.minutes,
        habitSchedule: HabitSchedule.daily,
        priority: TaskPriority.low,
        tag: '阅读',
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }
}
