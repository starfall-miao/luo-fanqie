import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 沉浸式专注页的系统能力：屏幕固定与常亮。
///
/// Android 上使用屏幕固定（pin）而不是设备管理员，用户可以随时用系统手势
/// 退出，符合透明、可退出的产品原则。其他平台全部降级为 no-op。
class ImmersiveModeService {
  const ImmersiveModeService();

  static const _channel = MethodChannel('dev.luofanqie/immersive');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> enter({required bool lockTask}) async {
    if (!_supported) return;
    await _invoke('keepScreenOn');
    if (lockTask) await _invoke('startLockTask');
  }

  Future<void> leave() async {
    if (!_supported) return;
    await _invoke('stopLockTask');
    await _invoke('clearKeepScreenOn');
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // 非 Android 环境或热重载时忽略。
    } on PlatformException catch (error) {
      debugPrint('沉浸式模式调用失败：${error.code} ${error.message}');
    }
  }
}
