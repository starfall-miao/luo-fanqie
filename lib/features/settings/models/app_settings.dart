import 'dart:convert';

/// 外观模式，与 Flutter 的 ThemeMode 解耦，便于持久化。
enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsPerLongBreak = 4,
    this.dailyGoalMinutes = 120,
    this.autoStartBreak = true,
    this.autoStartFocus = false,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.notificationsEnabled = true,
    this.strictMode = false,
    this.themeMode = AppThemeMode.system,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsPerLongBreak;
  final int dailyGoalMinutes;
  final bool autoStartBreak;
  final bool autoStartFocus;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool notificationsEnabled;
  final bool strictMode;
  final AppThemeMode themeMode;

  static const defaults = AppSettings();

  static int _clamp(int value, int min, int max, int fallback) {
    if (value < min || value > max) return fallback;
    return value;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const fallback = AppSettings.defaults;
    return AppSettings(
      focusMinutes: _clamp(
        (json['focusMinutes'] as num?)?.toInt() ?? 25,
        1,
        180,
        fallback.focusMinutes,
      ),
      shortBreakMinutes: _clamp(
        (json['shortBreakMinutes'] as num?)?.toInt() ?? 5,
        1,
        60,
        fallback.shortBreakMinutes,
      ),
      longBreakMinutes: _clamp(
        (json['longBreakMinutes'] as num?)?.toInt() ?? 15,
        1,
        120,
        fallback.longBreakMinutes,
      ),
      roundsPerLongBreak: _clamp(
        (json['roundsPerLongBreak'] as num?)?.toInt() ?? 4,
        2,
        8,
        fallback.roundsPerLongBreak,
      ),
      dailyGoalMinutes: _clamp(
        (json['dailyGoalMinutes'] as num?)?.toInt() ?? 120,
        15,
        720,
        fallback.dailyGoalMinutes,
      ),
      autoStartBreak: json['autoStartBreak'] as bool? ?? true,
      autoStartFocus: json['autoStartFocus'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      strictMode: json['strictMode'] as bool? ?? false,
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
    );
  }

  static AppSettings decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 数据损坏时回到默认配置，不阻塞启动。
    }
    return const AppSettings();
  }

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'focusMinutes': focusMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'roundsPerLongBreak': roundsPerLongBreak,
    'dailyGoalMinutes': dailyGoalMinutes,
    'autoStartBreak': autoStartBreak,
    'autoStartFocus': autoStartFocus,
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'notificationsEnabled': notificationsEnabled,
    'strictMode': strictMode,
    'themeMode': themeMode.name,
  };

  AppSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsPerLongBreak,
    int? dailyGoalMinutes,
    bool? autoStartBreak,
    bool? autoStartFocus,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? notificationsEnabled,
    bool? strictMode,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      roundsPerLongBreak: roundsPerLongBreak ?? this.roundsPerLongBreak,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      strictMode: strictMode ?? this.strictMode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
