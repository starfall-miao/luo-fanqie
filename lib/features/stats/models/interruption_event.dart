import '../../../core/utils/date_utils.dart';

/// 一次主动结束专注时记录下来的打断原因。
class InterruptionEvent {
  const InterruptionEvent({
    required this.id,
    required this.at,
    required this.reason,
    this.taskId,
    this.taskTitle = '自由专注',
    this.elapsedMinutes = 0,
  });

  final String id;
  final String? taskId;
  final String taskTitle;
  final String reason;
  final DateTime at;
  final int elapsedMinutes;

  String get dayKey => dateKey(at);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'reason': reason,
    'at': at.toIso8601String(),
    'elapsedMinutes': elapsedMinutes,
  };

  factory InterruptionEvent.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now();
    return InterruptionEvent(
      id: json['id'] as String? ?? 'interruption-${at.microsecondsSinceEpoch}',
      taskId: json['taskId'] as String?,
      taskTitle: json['taskTitle'] as String? ?? '自由专注',
      reason: json['reason'] as String? ?? '其他',
      at: at,
      elapsedMinutes: (json['elapsedMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}
