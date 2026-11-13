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
    this.strictOverlay = true,
    this.strictLockTask = false,
    this.strictDnd = false,
    this.strictExitMonth = '',
    this.strictExitUsed = 0,
    this.themeMode = AppThemeMode.system,
    this.glassEffects = false,
    this.companionEnabled = true,
    this.whitelistPackages = const <String>[],
    this.autoLockEnabled = false,
    this.autoLockHour = 21,
    this.autoLockMinute = 0,
    this.autoLockMinutes = 45,
    this.autoLockLastDate = '',
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

  /// 学霸模式拆分选项：切 App 全屏提醒、系统锁定任务、专注时勿扰。
  final bool strictOverlay;
  final bool strictLockTask;
  final bool strictDnd;
  final String strictExitMonth;
  final int strictExitUsed;

  final AppThemeMode themeMode;

  /// 毛玻璃需要实时采样背景，低端设备容易掉帧；默认关闭。
  final bool glassEffects;

  /// 是否显示落落看板娘。
  final bool companionEnabled;

  /// 严格专注/锁机时允许打开的应用包名。为空表示不允许任何其他 App。
  final List<String> whitelistPackages;

  /// 每日自动锁机计划。当前实现会在应用前台到点时自动开始；
  /// 应用不在前台时仍需用户回到应用后触发。
  final bool autoLockEnabled;
  final int autoLockHour;
  final int autoLockMinute;
  final int autoLockMinutes;
  final String autoLockLastDate;

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
      strictOverlay: json['strictOverlay'] as bool? ?? true,
      strictLockTask: json['strictLockTask'] as bool? ?? false,
      strictDnd: json['strictDnd'] as bool? ?? false,
      strictExitMonth: json['strictExitMonth'] as String? ?? '',
      strictExitUsed: (json['strictExitUsed'] as num?)?.toInt() ?? 0,
      glassEffects: json['glassEffects'] as bool? ?? false,
      companionEnabled: json['companionEnabled'] as bool? ?? true,
      whitelistPackages:
          (json['whitelistPackages'] as List?)?.whereType<String>().toList() ??
          const <String>[],
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
    'strictOverlay': strictOverlay,
    'strictLockTask': strictLockTask,
    'strictDnd': strictDnd,
    'strictExitMonth': strictExitMonth,
    'strictExitUsed': strictExitUsed,
    'glassEffects': glassEffects,
    'companionEnabled': companionEnabled,
    'whitelistPackages': whitelistPackages,
    'autoLockEnabled': autoLockEnabled,
    'autoLockHour': autoLockHour,
    'autoLockMinute': autoLockMinute,
    'autoLockMinutes': autoLockMinutes,
    'autoLockLastDate': autoLockLastDate,
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
    bool? strictOverlay,
    bool? strictLockTask,
    bool? strictDnd,
    String? strictExitMonth,
    int? strictExitUsed,
    bool? glassEffects,
    bool? companionEnabled,
    List<String>? whitelistPackages,
    bool? autoLockEnabled,
    int? autoLockHour,
    int? autoLockMinute,
    int? autoLockMinutes,
    String? autoLockLastDate,
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
      strictOverlay: strictOverlay ?? this.strictOverlay,
      strictLockTask: strictLockTask ?? this.strictLockTask,
      strictDnd: strictDnd ?? this.strictDnd,
      strictExitMonth: strictExitMonth ?? this.strictExitMonth,
      strictExitUsed: strictExitUsed ?? this.strictExitUsed,
      glassEffects: glassEffects ?? this.glassEffects,
      companionEnabled: companionEnabled ?? this.companionEnabled,
      whitelistPackages: whitelistPackages ?? this.whitelistPackages,
      autoLockEnabled: autoLockEnabled ?? this.autoLockEnabled,
      autoLockHour: autoLockHour ?? this.autoLockHour,
      autoLockMinute: autoLockMinute ?? this.autoLockMinute,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      autoLockLastDate: autoLockLastDate ?? this.autoLockLastDate,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
