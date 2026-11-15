import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/storage/key_value_storage.dart';
import 'models/custom_sound.dart';
import 'storage/custom_sound_storage.dart';

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
  SoundscapeController(this._storage) {
    _customSounds = _loadCustomSounds();
  }

  static const _customKey = 'luo_fanqie.custom_sounds.v1';

  final KeyValueStorage _storage;
  AudioPlayer? _player;
  Soundscape? _active;
  String? _activeCustomId;
  List<CustomSound> _customSounds = <CustomSound>[];
  double _volume = 0.55;
  String? _error;

  Soundscape? get active => _active;

  String? get activeCustomId => _activeCustomId;

  List<CustomSound> get customSounds =>
      List<CustomSound>.unmodifiable(_customSounds);

  bool get customSupported => !kIsWeb;

  List<CustomSound> _loadCustomSounds() {
    final raw = _storage.read(_customKey);
    if (raw == null || raw.isEmpty) return <CustomSound>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CustomSound>[];
      return decoded
          .whereType<Map>()
          .map((item) => CustomSound.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.fileName.isNotEmpty)
          .toList();
    } catch (_) {
      return <CustomSound>[];
    }
  }

  Future<void> _persistCustomSounds() => _storage.write(
    _customKey,
    jsonEncode(_customSounds.map((sound) => sound.toJson()).toList()),
  );

  Future<String?> addCustomFromUrl({
    required String name,
    required String url,
  }) async {
    if (!customSupported) return 'Web 端暂不支持自定义音频缓存';
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return '请填写 http(s) 音频直链';
    }
    _error = null;
    _loadingCustom = true;
    notifyListeners();
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        return '下载失败（HTTP ${response.statusCode}）';
      }
      final bytes = response.bodyBytes;
      if (bytes.length > 30 * 1024 * 1024) {
        return '音频超过 30MB，请换短一点的音频';
      }
      if (bytes.isEmpty) return '下载到空文件';
      var extension = uri.path.split('.').last.toLowerCase();
      if (!const [
        'mp3',
        'wav',
        'ogg',
        'm4a',
        'aac',
        'flac',
      ].contains(extension)) {
        extension = 'mp3';
      }
      final fileName =
          'custom_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final path = await saveCustomSoundFile(fileName, bytes);
      if (path == null) return '无法把音频保存到本机';
      final sound = CustomSound(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim().isEmpty ? '自定义音频' : name.trim(),
        fileName: fileName,
        addedAt: DateTime.now(),
      );
      _customSounds = [..._customSounds, sound];
      await _persistCustomSounds();
      return null;
    } catch (error) {
      return '下载音频失败：$error';
    } finally {
      _loadingCustom = false;
      notifyListeners();
    }
  }

  bool _loadingCustom = false;

  bool get loadingCustom => _loadingCustom;

  Future<void> toggleCustom(CustomSound sound) async {
    if (_activeCustomId == sound.id) {
      await stop();
      return;
    }
    try {
      _error = null;
      final path = await customSoundFilePath(sound.fileName);
      if (path == null) {
        _error = '自定义音频文件已不在本机，请重新添加';
        notifyListeners();
        return;
      }
      _active = null;
      _activeCustomId = sound.id;
      notifyListeners();
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
      await player.play(DeviceFileSource(path));
    } catch (error) {
      _activeCustomId = null;
      _error = '自定义音频播放失败：$error';
      notifyListeners();
    }
  }

  Future<void> removeCustom(CustomSound sound) async {
    if (_activeCustomId == sound.id) await stop();
    _customSounds = _customSounds
        .where((item) => item.id != sound.id)
        .toList(growable: false);
    notifyListeners();
    await deleteCustomSoundFile(sound.fileName);
    await _persistCustomSounds();
  }

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
      _activeCustomId = null;
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
    _activeCustomId = null;
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
