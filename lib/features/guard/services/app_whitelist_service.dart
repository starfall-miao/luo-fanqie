import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.label,
    required this.packageName,
    this.isEducation = false,
  });

  final String label;
  final String packageName;
  final bool isEducation;
}

/// 读取可启动应用列表。仅 Android；只用于用户手动维护白名单。
class AppWhitelistService {
  const AppWhitelistService();

  static const _channel = MethodChannel('dev.luofanqie/apps');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<InstalledApp>> listApps() async {
    if (!supported) return const <InstalledApp>[];
    try {
      final raw = await _channel.invokeMethod<String>('listApps');
      if (raw == null || raw.isEmpty) return const <InstalledApp>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <InstalledApp>[];
      final apps = decoded
          .whereType<Map>()
          .map(
            (item) => InstalledApp(
              label:
                  item['label'] as String? ??
                  item['packageName'] as String? ??
                  '',
              packageName: item['packageName'] as String? ?? '',
            ),
          )
          .where((app) => app.packageName.isNotEmpty)
          .toList();
      apps.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return apps;
    } on MissingPluginException {
      return const <InstalledApp>[];
    } on PlatformException catch (error) {
      debugPrint('读取应用列表失败：${error.message}');
      return const <InstalledApp>[];
    }
  }

  Future<bool> launchApp(String packageName) async {
    if (!supported || packageName.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('launchApp', <String, Object>{
            'packageName': packageName,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('启动应用失败：${error.message}');
      return false;
    }
  }
}
