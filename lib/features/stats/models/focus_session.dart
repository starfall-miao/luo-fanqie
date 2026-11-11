import '../../../core/utils/date_utils.dart';

/// 一次完成的专注记录。只有完整走完的专注阶段会被记录，跳过不计入。
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.minutes,
    this.taskId,
    this.taskTitle = '自由专注',
  });

  final String id;
  final String? taskId;
  final String taskTitle;
  final DateTime startedAt;
  final DateTime endedAt;
  final int minutes;

  String get dayKey => dateKey(endedAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'minutes': minutes,
  };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    final endedAt =
        DateTime.tryParse(json['endedAt'] as String? ?? '') ?? DateTime.now();
    final startedAt =
        DateTime.tryParse(json['startedAt'] as String? ?? '') ??
        endedAt.subtract(
          Duration(minutes: (json['minutes'] as num?)?.toInt() ?? 25),
        );
    return FocusSession(
      id: json['id'] as String? ?? 'session-${endedAt.microsecondsSinceEpoch}',
      taskId: json['taskId'] as String?,
      taskTitle: json['taskTitle'] as String? ?? '自由专注',
      startedAt: startedAt,
      endedAt: endedAt,
      minutes: (json['minutes'] as num?)?.toInt() ?? 25,
    );
  }
}

class DayStat {
  const DayStat({
    required this.date,
    required this.sessions,
    required this.minutes,
  });

  final DateTime date;
  final int sessions;
  final int minutes;

  bool get isEmpty => sessions == 0;
}
