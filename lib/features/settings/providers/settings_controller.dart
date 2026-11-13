import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/storage/key_value_storage.dart';
import '../models/app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._storage) {
    final raw = _storage.read(_storageKey);
    if (raw != null) _settings = AppSettings.decode(raw);
  }

  static const _storageKey = 'luo_fanqie.settings.v1';

  final KeyValueStorage _storage;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  ThemeMode get themeMode => switch (_settings.themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  void _apply(AppSettings next) {
    if (identical(next, _settings)) return;
    _settings = next;
    unawaited(_storage.write(_storageKey, next.encode()));
    notifyListeners();
  }

  void setFocusMinutes(int value) =>
      _apply(_settings.copyWith(focusMinutes: value.clamp(1, 180)));

  void setShortBreakMinutes(int value) =>
      _apply(_settings.copyWith(shortBreakMinutes: value.clamp(1, 60)));

  void setLongBreakMinutes(int value) =>
      _apply(_settings.copyWith(longBreakMinutes: value.clamp(1, 120)));

  void setRoundsPerLongBreak(int value) =>
      _apply(_settings.copyWith(roundsPerLongBreak: value.clamp(2, 8)));

  void setDailyGoalMinutes(int value) =>
      _apply(_settings.copyWith(dailyGoalMinutes: value.clamp(15, 720)));

  void setAutoStartBreak(bool value) =>
      _apply(_settings.copyWith(autoStartBreak: value));

  void setAutoStartFocus(bool value) =>
      _apply(_settings.copyWith(autoStartFocus: value));

  void setSoundEnabled(bool value) =>
      _apply(_settings.copyWith(soundEnabled: value));

  void setHapticsEnabled(bool value) =>
      _apply(_settings.copyWith(hapticsEnabled: value));

  void setNotificationsEnabled(bool value) =>
      _apply(_settings.copyWith(notificationsEnabled: value));

  void setStrictMode(bool value) =>
      _apply(_settings.copyWith(strictMode: value));

  void setStrictOverlay(bool value) =>
      _apply(_settings.copyWith(strictOverlay: value));

  void setStrictLockTask(bool value) =>
      _apply(_settings.copyWith(strictLockTask: value));

  void setStrictDnd(bool value) => _apply(_settings.copyWith(strictDnd: value));

  int get strictExitsRemaining {
    final monthKey = _monthKey(DateTime.now());
    if (_settings.strictExitMonth != monthKey) return 3;
    return (3 - _settings.strictExitUsed).clamp(0, 3);
  }

  void consumeStrictExit() {
    final now = DateTime.now();
    final monthKey = _monthKey(now);
    final used = _settings.strictExitMonth == monthKey
        ? _settings.strictExitUsed + 1
        : 1;
    _apply(
      _settings.copyWith(
        strictExitMonth: monthKey,
        strictExitUsed: used.clamp(0, 3),
      ),
    );
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  void setGlassEffects(bool value) =>
      _apply(_settings.copyWith(glassEffects: value));

  void setCompanionEnabled(bool value) =>
      _apply(_settings.copyWith(companionEnabled: value));

  void setWhitelistPackages(List<String> packages) => _apply(
    _settings.copyWith(whitelistPackages: List.unmodifiable(packages)),
  );

  void setAutoLockEnabled(bool value) =>
      _apply(_settings.copyWith(autoLockEnabled: value));

  void setAutoLockTime(int hour, int minute) => _apply(
    _settings.copyWith(
      autoLockHour: hour.clamp(0, 23),
      autoLockMinute: minute.clamp(0, 59),
    ),
  );

  void setAutoLockMinutes(int value) =>
      _apply(_settings.copyWith(autoLockMinutes: value.clamp(5, 180)));

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? nextAutoLockTime([DateTime? now]) {
    if (!_settings.autoLockEnabled) return null;
    final current = now ?? DateTime.now();
    var candidate = DateTime(
      current.year,
      current.month,
      current.day,
      _settings.autoLockHour,
      _settings.autoLockMinute,
    );
    final alreadyStarted = _settings.autoLockLastDate == _dayKey(current);
    if (alreadyStarted || !candidate.isAfter(current)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  void markAutoLockStarted(DateTime now) =>
      _apply(_settings.copyWith(autoLockLastDate: _dayKey(now)));

  void setThemeMode(AppThemeMode value) =>
      _apply(_settings.copyWith(themeMode: value));

  void resetToDefaults() => _apply(const AppSettings());
}
