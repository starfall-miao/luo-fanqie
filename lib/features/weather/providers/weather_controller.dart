// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_storage.dart';
import '../../settings/providers/settings_controller.dart';
import '../models/weather_snapshot.dart';
import '../services/open_meteo_service.dart';

class WeatherController extends ChangeNotifier {
  WeatherController({
    required KeyValueStorage storage,
    required SettingsController settings,
    OpenMeteoService service = const OpenMeteoService(),
  }) : _storage = storage,
       _settings = settings,
       _service = service {
    _snapshot = _loadCached();
    _settings.addListener(_onSettingsChanged);
    if (_settings.settings.weatherBackgroundEnabled) {
      unawaited(refresh());
    }
  }

  static const _cacheKey = 'luo_fanqie.weather.v1';

  final KeyValueStorage _storage;
  final SettingsController _settings;
  final OpenMeteoService _service;
  WeatherSnapshot? _snapshot;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  WeatherSnapshot? get snapshot => _snapshot;

  bool get loading => _loading;

  String? get error => _error;

  bool get enabled => _settings.settings.weatherBackgroundEnabled;

  WeatherCity get city => weatherCities.firstWhere(
    (item) => item.name == _settings.settings.weatherCity,
    orElse: () => weatherCities[1],
  );

  WeatherSnapshot? _loadCached() {
    final raw = _storage.read(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return WeatherSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  void _onSettingsChanged() {
    if (!enabled) {
      _timer?.cancel();
      return;
    }
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!enabled || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _service.fetch(city);
      _snapshot = snapshot;
      await _storage.write(_cacheKey, jsonEncode(snapshot.toJson()));
      _scheduleRefresh();
    } catch (error) {
      _error = '天气更新失败，先使用上次缓存';
      debugPrint('天气更新失败：$error');
      _snapshot ??= WeatherSnapshot(
        city: city.name,
        condition: WeatherCondition.partlyCloudy,
        temperature: 20,
        isDay: DateTime.now().hour >= 6 && DateTime.now().hour < 19,
        fetchedAt: DateTime.now(),
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 30), () {
      if (enabled) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _timer?.cancel();
    super.dispose();
  }
}
