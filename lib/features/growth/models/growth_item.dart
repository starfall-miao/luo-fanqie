import '../../../core/utils/date_utils.dart';

import 'dart:math' as math;

enum GrowthType { habit, goal, learning }

extension GrowthTypeX on GrowthType {
  String get label => switch (this) {
    GrowthType.habit => '习惯',
    GrowthType.goal => '长期目标',
    GrowthType.learning => '学习计划',
  };
}

class GrowthItem {
  const GrowthItem({
    required this.id,
    required this.title,
    required this.type,
    this.area = '成长',
    this.note = '',
    this.target = 30,
    this.progress = 0,
    this.streak = 0,
    this.totalCheckIns = 0,
    this.lastCheckInDate = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final GrowthType type;
  final String area;
  final String note;
  final int target;
  final double progress;
  final int streak;
  final int totalCheckIns;
  final String lastCheckInDate;
  final DateTime? createdAt;

  bool get isHabit => type == GrowthType.habit;
  bool checkedOn(DateTime date) => lastCheckInDate == dateKey(date);

  bool get checkedToday => checkedOn(DateTime.now());
  double get ratio => target <= 0 ? 0 : (progress / target).clamp(0, 1);

  GrowthItem copyWith({
    String? title,
    GrowthType? type,
    String? area,
    String? note,
    int? target,
    double? progress,
    int? streak,
    int? totalCheckIns,
    String? lastCheckInDate,
  }) {
    return GrowthItem(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      area: area ?? this.area,
      note: note ?? this.note,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      streak: streak ?? this.streak,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'type': type.name,
    'area': area,
    'note': note,
    'target': target,
    'progress': progress,
    'streak': streak,
    'totalCheckIns': totalCheckIns,
    'lastCheckInDate': lastCheckInDate,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory GrowthItem.fromJson(Map<String, dynamic> json) {
    return GrowthItem(
      id:
          json['id'] as String? ??
          'growth-${DateTime.now().microsecondsSinceEpoch}',
      title: json['title'] as String? ?? '未命名',
      type: GrowthType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => GrowthType.habit,
      ),
      area: json['area'] as String? ?? '成长',
      note: json['note'] as String? ?? '',
      target: math.max(1, (json['target'] as num?)?.toInt() ?? 30),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
      lastCheckInDate: json['lastCheckInDate'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
