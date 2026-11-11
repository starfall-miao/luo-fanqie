import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 番茄计时通知。当前只在 Android 上生效，其他平台使用空实现。
abstract interface class TimerNotificationService {
  Future<void> requestPermission();

  Future<void> schedule({
    required DateTime fireAt,
    required String title,
    required String body,
  });

  Future<void> cancel();
}

class NoopTimerNotificationService implements TimerNotificationService {
  const NoopTimerNotificationService();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule({
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

/// 通过原生 AlarmManager 在计时结束时发系统通知。
///
/// 选择原生实现而不是引入通知插件，是为了避免 Web/桌面构建被平台插件牵连。
class AndroidTimerNotificationService implements TimerNotificationService {
  const AndroidTimerNotificationService();

  static const _channel = MethodChannel('dev.luofanqie/notifications');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> requestPermission() async {
    if (!_supported) return;
    await _invoke('requestPermission');
  }

  @override
  Future<void> schedule({
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await _invoke('schedule', {
      'fireAtMillis': fireAt.millisecondsSinceEpoch,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    await _invoke('cancel');
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 例如热重载或非 Android 构建中缺少原生实现。
    } on PlatformException catch (error) {
      debugPrint('通知调度失败：${error.code} ${error.message}');
    }
  }
}
