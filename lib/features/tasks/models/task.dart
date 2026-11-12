import 'dart:math' as math;

import '../../../core/utils/date_utils.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => '低',
    TaskPriority.medium => '中',
    TaskPriority.high => '高',
  };

  int get weight => switch (this) {
    TaskPriority.low => 0,
    TaskPriority.medium => 1,
    TaskPriority.high => 2,
  };
}

/// 待办类型：普通番茄、定目标、养习惯。
enum TaskKind { pomodoro, goal, habit }

extension TaskKindX on TaskKind {
  String get label => switch (this) {
    TaskKind.pomodoro => '普通番茄',
    TaskKind.goal => '定目标',
    TaskKind.habit => '养习惯',
  };

  String get shortLabel => switch (this) {
    TaskKind.pomodoro => '普通',
    TaskKind.goal => '目标',
    TaskKind.habit => '习惯',
  };
}

enum TaskUnit { minutes, hours, times, custom }

extension TaskUnitX on TaskUnit {
  String get label => switch (this) {
    TaskUnit.minutes => '分钟',
    TaskUnit.hours => '小时',
    TaskUnit.times => '次数',
    TaskUnit.custom => '自定义',
  };
}

/// 习惯周期：每天、每周选几天、每月选几天，或每周/每月完成量。
enum HabitSchedule { daily, weekdays, monthDays, weeklyQuota, monthlyQuota }

extension HabitScheduleX on HabitSchedule {
  String get label => switch (this) {
    HabitSchedule.daily => '每天',
    HabitSchedule.weekdays => '每周选几天',
    HabitSchedule.monthDays => '每月选几天',
    HabitSchedule.weeklyQuota => '每周完成量',
    HabitSchedule.monthlyQuota => '每月完成量',
  };

  bool get isQuota =>
      this == HabitSchedule.weeklyQuota || this == HabitSchedule.monthlyQuota;
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.priority = TaskPriority.medium,
    this.tag = '',
    this.kind = TaskKind.pomodoro,
    this.focusMinutes = 25,
    this.targetAmount,
    this.targetUnit = TaskUnit.times,
    this.customUnit = '',
    this.habitSchedule = HabitSchedule.daily,
    this.weekdays = const <int>[],
    this.monthDays = const <int>[],
    this.progressAmount = 0,
    this.progressPeriodKey,
    this.dueDate,
    this.done = false,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String notes;

  /// 兼容旧数据与普通任务统计的番茄数。
  final int estimatedPomodoros;
  final int completedPomodoros;
  final TaskPriority priority;

  /// 用户自由填写的标签，空字符串表示无标签。
  final String tag;

  final TaskKind kind;

  /// 这个待办/习惯单次专注时长。
  final int focusMinutes;

  /// 目标总量，或习惯在周期内的目标量。
  final double? targetAmount;
  final TaskUnit targetUnit;
  final String customUnit;

  /// 习惯的周期规则。
  final HabitSchedule habitSchedule;
  final List<int> weekdays;
  final List<int> monthDays;

  /// 已完成量；习惯会随周期变化重置。
  final double progressAmount;
  final String? progressPeriodKey;

  final DateTime? dueDate;
  final bool done;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// 最后修改时间，用于多设备同步时判断版本新旧；旧数据回退到创建时间。
  final DateTime? updatedAt;

  DateTime get lastModified => updatedAt ?? createdAt;

  bool get isGoal => kind == TaskKind.goal;

  bool get isHabit => kind == TaskKind.habit;

  bool get hasTarget => targetAmount != null && targetAmount! > 0;

  String get unitLabel => switch (targetUnit) {
    TaskUnit.minutes => '分钟',
    TaskUnit.hours => '小时',
    TaskUnit.times => '次',
    TaskUnit.custom => customUnit.trim().isEmpty ? '量' : customUnit.trim(),
  };

  /// 每完成一次 [minutes] 分钟专注给这个待办贡献多少进度。
  double amountForFocus(int minutes) => switch (targetUnit) {
    TaskUnit.minutes => minutes.toDouble(),
    TaskUnit.hours => minutes / 60,
    TaskUnit.times || TaskUnit.custom => 1,
  };

  String periodKeyFor(DateTime now) {
    if (!isHabit) return 'all';
    return switch (habitSchedule) {
      HabitSchedule.daily ||
      HabitSchedule.weekdays ||
      HabitSchedule.monthDays => 'day-${dateKey(now)}',
      HabitSchedule.weeklyQuota => 'week-${dateKey(startOfWeek(now))}',
      HabitSchedule.monthlyQuota =>
        'month-${now.year}-${now.month.toString().padLeft(2, '0')}',
    };
  }

  String periodLabel(DateTime now) {
    if (!isHabit) return '累计';
    return switch (habitSchedule) {
      HabitSchedule.weeklyQuota => '本周',
      HabitSchedule.monthlyQuota => '本月',
      _ => '今日',
    };
  }

  double effectiveProgress(DateTime now) {
    if (!isHabit) return progressAmount;
    return progressPeriodKey == periodKeyFor(now) ? progressAmount : 0;
  }

  double progressRatio(DateTime now) {
    if (!hasTarget) return 0;
    return (effectiveProgress(now) / targetAmount!).clamp(0.0, 1.0);
  }

  double get estimatedProgress {
    if (estimatedPomodoros <= 0) return 0;
    return (completedPomodoros / estimatedPomodoros).clamp(0.0, 1.0);
  }

  /// 例如「每天」「每周一、三、五」。
  String scheduleLabel() {
    if (!isHabit) return '';
    return switch (habitSchedule) {
      HabitSchedule.daily => '每天',
      HabitSchedule.weekdays =>
        weekdays.isEmpty
            ? '每周'
            : '每周${weekdays.map((day) => _weekdayName(day)).join('、')}',
      HabitSchedule.monthDays =>
        monthDays.isEmpty
            ? '每月'
            : '每月${monthDays.map((day) => '$day').join('、')}日',
      HabitSchedule.weeklyQuota => '每周',
      HabitSchedule.monthlyQuota => '每月',
    };
  }

  bool scheduledOn(DateTime date) {
    if (!isHabit) return true;
    return switch (habitSchedule) {
      HabitSchedule.daily => true,
      HabitSchedule.weekdays => weekdays.contains(date.weekday),
      HabitSchedule.monthDays => monthDays.contains(date.day),
      HabitSchedule.weeklyQuota || HabitSchedule.monthlyQuota => true,
    };
  }

  String formatAmount(double value) {
    if (value.abs() < 0.05) return '0';
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String progressLabel(DateTime now) {
    final progress = effectiveProgress(now);
    return '${formatAmount(progress)} / ${formatAmount(targetAmount ?? 0)} $unitLabel';
  }

  bool isOverdue({DateTime? now}) {
    if (done || dueDate == null) return false;
    return startOfDay(dueDate!).isBefore(startOfDay(now ?? DateTime.now()));
  }

  Task copyWith({
    String? title,
    String? notes,
    int? estimatedPomodoros,
    int? completedPomodoros,
    TaskPriority? priority,
    String? tag,
    TaskKind? kind,
    int? focusMinutes,
    double? targetAmount,
    bool clearTargetAmount = false,
    TaskUnit? targetUnit,
    String? customUnit,
    HabitSchedule? habitSchedule,
    List<int>? weekdays,
    List<int>? monthDays,
    double? progressAmount,
    String? progressPeriodKey,
    bool clearProgressPeriod = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      priority: priority ?? this.priority,
      tag: tag ?? this.tag,
      kind: kind ?? this.kind,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      targetAmount: clearTargetAmount
          ? null
          : targetAmount ?? this.targetAmount,
      targetUnit: targetUnit ?? this.targetUnit,
      customUnit: customUnit ?? this.customUnit,
      habitSchedule: habitSchedule ?? this.habitSchedule,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
      progressAmount: progressAmount ?? this.progressAmount,
      progressPeriodKey: clearProgressPeriod
          ? null
          : progressPeriodKey ?? this.progressPeriodKey,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      done: done ?? this.done,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'notes': notes,
    'estimatedPomodoros': estimatedPomodoros,
    'completedPomodoros': completedPomodoros,
    'priority': priority.name,
    'tag': tag,
    'kind': kind.name,
    'focusMinutes': focusMinutes,
    'targetAmount': targetAmount,
    'targetUnit': targetUnit.name,
    'customUnit': customUnit,
    'habitSchedule': habitSchedule.name,
    'weekdays': weekdays,
    'monthDays': monthDays,
    'progressAmount': progressAmount,
    'progressPeriodKey': progressPeriodKey,
    'dueDate': dueDate?.toIso8601String(),
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final completedAt = DateTime.tryParse(json['completedAt'] as String? ?? '');
    final dueDate = DateTime.tryParse(json['dueDate'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final rawWeekdays = json['weekdays'];
    final rawMonthDays = json['monthDays'];
    final weekdays = rawWeekdays is List
        ? rawWeekdays
              .whereType<num>()
              .map((day) => day.toInt())
              .where((day) => day >= 1 && day <= 7)
              .toSet()
              .toList()
        : <int>[];
    final monthDays = rawMonthDays is List
        ? rawMonthDays
              .whereType<num>()
              .map((day) => day.toInt())
              .where((day) => day >= 1 && day <= 31)
              .toSet()
              .toList()
        : <int>[];
    final tag = (json['tag'] as String? ?? '').trim();
    return Task(
      id: json['id'] as String? ?? 'task-${createdAt.microsecondsSinceEpoch}',
      title: (json['title'] as String? ?? '').trim(),
      notes: json['notes'] as String? ?? '',
      estimatedPomodoros: math.max(
        1,
        (json['estimatedPomodoros'] as num?)?.toInt() ?? 1,
      ),
      completedPomodoros: math.max(
        0,
        (json['completedPomodoros'] as num?)?.toInt() ?? 0,
      ),
      priority: TaskPriority.values.firstWhere(
        (priority) => priority.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      tag: tag,
      kind: TaskKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => TaskKind.pomodoro,
      ),
      focusMinutes: math.max(1, (json['focusMinutes'] as num?)?.toInt() ?? 25),
      targetAmount: (json['targetAmount'] as num?)?.toDouble(),
      targetUnit: TaskUnit.values.firstWhere(
        (unit) => unit.name == json['targetUnit'],
        orElse: () => TaskUnit.times,
      ),
      customUnit: json['customUnit'] as String? ?? '',
      habitSchedule: HabitSchedule.values.firstWhere(
        (schedule) => schedule.name == json['habitSchedule'],
        orElse: () => HabitSchedule.daily,
      ),
      weekdays: weekdays,
      monthDays: monthDays,
      progressAmount: math.max(
        0,
        (json['progressAmount'] as num?)?.toDouble() ?? 0,
      ),
      progressPeriodKey: json['progressPeriodKey'] as String?,
      dueDate: dueDate == null ? null : startOfDay(dueDate),
      done: json['done'] as bool? ?? false,
      createdAt: createdAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }

  /// 未完成在前；未完成按优先级、截止日期、创建时间排序。
  static int compareForDisplay(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.done) {
      final ac = a.completedAt ?? a.createdAt;
      final bc = b.completedAt ?? b.createdAt;
      return bc.compareTo(ac);
    }
    final priority = b.priority.weight.compareTo(a.priority.weight);
    if (priority != 0) return priority;
    if (a.dueDate != null && b.dueDate != null) {
      final due = a.dueDate!.compareTo(b.dueDate!);
      if (due != 0) return due;
    } else if (a.dueDate != null) {
      return -1;
    } else if (b.dueDate != null) {
      return 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  static String _weekdayName(int weekday) => switch (weekday) {
    1 => '一',
    2 => '二',
    3 => '三',
    4 => '四',
    5 => '五',
    6 => '六',
    7 => '日',
    _ => '',
  };
}
