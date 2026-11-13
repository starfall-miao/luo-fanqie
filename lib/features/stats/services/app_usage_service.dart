import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUsageEntry {
  const AppUsageEntry({
    required this.label,
    required this.packageName,
    required this.minutes,
  });

  final String label;
  final String packageName;
  final int minutes;
}

class AppUsageService {
  const AppUsageService();

  static const _channel = MethodChannel('dev.luofanqie/usage');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasAccess() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on MissingPluginException {
      // 桌面/Web 无此页面。
    } on PlatformException catch (error) {
      debugPrint('打开使用情况设置失败：${error.message}');
    }
  }

  Future<List<AppUsageEntry>> query({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!supported) return const <AppUsageEntry>[];
    try {
      final raw = await _channel.invokeMethod<String>(
        'queryUsage',
        <String, Object>{
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        },
      );
      if (raw == null || raw.isEmpty) return const <AppUsageEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AppUsageEntry>[];
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) => AppUsageEntry(
              label: item['label'] as String? ?? '',
              packageName: item['packageName'] as String? ?? '',
              minutes: (item['minutes'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((entry) => entry.minutes > 0)
          .toList();
      entries.sort((a, b) => b.minutes.compareTo(a.minutes));
      return entries;
    } on MissingPluginException {
      return const <AppUsageEntry>[];
    } on PlatformException catch (error) {
      debugPrint('读取应用使用情况失败：${error.message}');
      return const <AppUsageEntry>[];
    }
  }
}
