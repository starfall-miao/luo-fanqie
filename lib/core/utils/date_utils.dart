import 'dart:math' as math;

/// 与日期相关的纯函数工具。全部使用设备本地时间。
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// 以周一为一周的第一天。
DateTime startOfWeek(DateTime date) {
  final day = startOfDay(date);
  return addDays(day, 1 - day.weekday);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime date, {DateTime? now}) =>
    isSameDay(date, now ?? DateTime.now());

String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

const _weekdayShort = ['一', '二', '三', '四', '五', '六', '日'];

String weekdayShort(DateTime date) => _weekdayShort[date.weekday - 1];

/// 「今天」「明天」「昨天」「周五」或「11月20日」。
String relativeDayLabel(DateTime date, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  final target = startOfDay(date);
  final diff = target.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  if (diff > 1 && diff < 7) return '周${weekdayShort(target)}';
  if (diff < -1 && diff > -7) return '${-diff} 天前';
  return '${target.month}月${target.day}日';
}

/// 「今天」「明天」「11月8日 周六」。
String dueDateLabel(DateTime date, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  final target = startOfDay(date);
  final diff = target.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  return '${target.month}月${target.day}日 周${weekdayShort(target)}';
}

String greetingForHour(int hour) {
  if (hour < 5) return '夜深了';
  if (hour < 9) return '早上好';
  if (hour < 12) return '上午好';
  if (hour < 14) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

String clockLabel(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 将秒数格式化为 mm:ss（向上取整，保证一开始显示完整时长）。
String timerLabel(int remainingMillis) {
  final totalSeconds = math.max(0, (remainingMillis / 1000).ceil());
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// 用于「累计专注」等大数字场景。
String compactMinutes(int minutes) {
  if (minutes < 60) return '$minutes';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours' : '$hours.${(rest / 60 * 10).round()}';
}

String compactMinutesUnit(int minutes) => minutes < 60 ? '分钟' : '小时';
