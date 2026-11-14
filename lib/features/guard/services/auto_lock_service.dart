import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 每日自动锁机的原生闹钟与后台启动准备项。
class AutoLockService {
  const AutoLockService();

  static const _channel = MethodChannel('dev.luofanqie/immersive');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> schedule({required int hour, required int minute}) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('scheduleAutoLock', {
        'hour': hour,
        'minute': minute,
      });
    } on MissingPluginException {
      // 测试/桌面端忽略。
    } on PlatformException catch (error) {
      debugPrint('自动锁机调度失败：${error.message}');
    }
  }

  Future<void> cancel() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('cancelAutoLock');
    } on MissingPluginException {
      // 忽略。
    } on PlatformException catch (error) {
      debugPrint('取消自动锁机失败：${error.message}');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on MissingPluginException {
      // 忽略。
    } on PlatformException catch (error) {
      debugPrint('请求忽略电池优化失败：${error.message}');
    }
  }

  Future<void> openAutostartSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('openAutostartSettings');
    } on MissingPluginException {
      // 忽略。
    } on PlatformException catch (error) {
      debugPrint('打开自启动设置失败：${error.message}');
    }
  }
}
