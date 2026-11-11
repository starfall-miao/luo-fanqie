import 'dart:math';

final Random _random = Random();

/// 轻量 ID：时间戳 + 随机后缀，足够单机应用去重。
String newId([String prefix = 'id']) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final suffix = _random.nextInt(1 << 20).toRadixString(36);
  return '$prefix-$time-$suffix';
}
