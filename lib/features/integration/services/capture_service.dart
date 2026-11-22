import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CaptureService {
  const CaptureService();

  static const _channel = MethodChannel('dev.luofanqie/immersive');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> setTarget(String packageName) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setCaptureTarget', {
        'packageName': packageName,
      });
    } on MissingPluginException {
      // 忽略测试/桌面端。
    } on PlatformException {
      // 忽略。
    }
  }

  Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isCaptureServiceEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('openCaptureAccessibilitySettings');
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  Future<List<String>> consumePending() async {
    if (!supported) return const <String>[];
    try {
      final raw = await _channel.invokeMethod<String>('consumePendingCapture');
      if (raw == null || raw.isEmpty) return const <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .whereType<String>()
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }
}
