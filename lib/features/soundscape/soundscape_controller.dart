import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Soundscape { rain, waves, fire }

extension SoundscapeX on Soundscape {
  String get label => switch (this) {
    Soundscape.rain => '细雨',
    Soundscape.waves => '海浪',
    Soundscape.fire => '篝火',
  };

  String get asset => switch (this) {
    Soundscape.rain => 'sounds/rain.wav',
    Soundscape.waves => 'sounds/waves.wav',
    Soundscape.fire => 'sounds/fire.wav',
  };
}

/// 本地生成并打包的环境音，不发起任何网络请求。
class SoundscapeController extends ChangeNotifier {
  AudioPlayer? _player;
  Soundscape? _active;
  double _volume = 0.55;
  String? _error;

  Soundscape? get active => _active;

  double get volume => _volume;

  String? get error => _error;

  Future<void> toggle(Soundscape soundscape) async {
    if (_active == soundscape) {
      await stop();
      return;
    }
    try {
      _error = null;
      _active = soundscape;
      notifyListeners();
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
      await player.play(AssetSource(soundscape.asset));
    } catch (error) {
      _active = null;
      _error = '环境音播放失败：$error';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // 无音频设备或测试环境中静默失败即可。
      }
    }
    _active = null;
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
    final player = _player;
    if (player != null) {
      try {
        await player.setVolume(_volume);
      } catch (_) {
        // 忽略音频设备错误。
      }
    }
  }

  @override
  void dispose() {
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose().catchError((_) {}));
    }
    super.dispose();
  }
}
