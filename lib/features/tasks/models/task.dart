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

/// 预设标签。用户只能从这些标签中选择，保证颜色与统计的一致性。
const List<String> kTaskTags = ['学习', '工作', '生活', '阅读', '运动'];

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.priority = TaskPriority.medium,
    this.tag = '学习',
    this.dueDate,
    this.done = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String notes;
  final int estimatedPomodoros;
  final int completedPomodoros;
  final TaskPriority priority;
  final String tag;
  final DateTime? dueDate;
  final bool done;
  final DateTime createdAt;
  final DateTime? completedAt;

  double get progress {
    if (estimatedPomodoros <= 0) return 0;
    return (completedPomodoros / estimatedPomodoros).clamp(0.0, 1.0);
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
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      priority: priority ?? this.priority,
      tag: tag ?? this.tag,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      done: done ?? this.done,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
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
    'dueDate': dueDate?.toIso8601String(),
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final completedAt = DateTime.tryParse(json['completedAt'] as String? ?? '');
    final dueDate = DateTime.tryParse(json['dueDate'] as String? ?? '');
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
      tag: kTaskTags.contains(json['tag']) ? json['tag'] as String : '学习',
      dueDate: dueDate == null ? null : startOfDay(dueDate),
      done: json['done'] as bool? ?? false,
      createdAt: createdAt,
      completedAt: completedAt,
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
}
