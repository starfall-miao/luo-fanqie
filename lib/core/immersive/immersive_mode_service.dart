import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 沉浸式专注页的系统能力。
///
/// 学霸守护使用 Android 无障碍服务绘制全屏置顶提醒：
/// 只在开启学霸模式期间读取当前前台应用包名，不读取屏幕内容；
/// 用户可随时点「结束守护」或在系统设置中关闭服务。
class ImmersiveModeService {
  const ImmersiveModeService();

  static const _channel = MethodChannel('dev.luofanqie/immersive');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> enter() async {
    if (!supported) return;
    await _invoke<void>('keepScreenOn');
  }

  Future<void> leave() async {
    if (!supported) return;
    await _invoke<void>('stopStrictGuard');
    await _invoke<void>('stopLockTask');
    await _invoke<void>('stopDnd');
    await _invoke<void>('clearKeepScreenOn');
  }

  Future<void> startLockTask() async {
    if (!supported) return;
    await _invoke<void>('startLockTask');
  }

  Future<void> stopLockTask() async {
    if (!supported) return;
    await _invoke<void>('stopLockTask');
  }

  Future<bool> isDndAccessGranted() async {
    if (!supported) return false;
    return await _invoke<bool>('isDndAccessGranted') ?? false;
  }

  Future<void> openDndAccessSettings() async {
    if (!supported) return;
    await _invoke<void>('openDndAccessSettings');
  }

  Future<bool> startDnd() async {
    if (!supported) return false;
    return await _invoke<bool>('startDnd') ?? false;
  }

  Future<void> stopDnd() async {
    if (!supported) return;
    await _invoke<void>('stopDnd');
  }

  /// 专注自然结束时使用：保留学霸守护的到点回跳，仅关闭常亮。
  Future<void> clearKeepScreenOn() async {
    if (!supported) return;
    await _invoke<void>('clearKeepScreenOn');
  }

  Future<bool> isStrictGuardEnabled() async {
    if (!supported) return false;
    return await _invoke<bool>('isStrictGuardEnabled') ?? false;
  }

  Future<void> openAccessibilitySettings() async {
    if (!supported) return;
    await _invoke<void>('openAccessibilitySettings');
  }

  Future<bool> startStrictGuard({
    required DateTime endAt,
    required String title,
  }) async {
    if (!supported) return false;
    return await _invoke<bool>('startStrictGuard', <String, Object>{
          'endAtMillis': endAt.millisecondsSinceEpoch,
          'title': title,
        }) ??
        false;
  }

  Future<void> stopStrictGuard() async {
    if (!supported) return;
    await _invoke<void>('stopStrictGuard');
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('沉浸式模式调用失败：${error.code} ${error.message}');
      return null;
    }
  }
}
