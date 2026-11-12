import 'package:flutter/material.dart';

/// 暮色番茄配色：暖奶油、番茄红与落日琥珀。
abstract final class AppPalette {
  static const tomato = Color(0xFFE85B3C);
  static const tomatoDeep = Color(0xFFC9472D);
  static const coral = Color(0xFFFF8A65);
  static const apricot = Color(0xFFF4A261);
  static const sun = Color(0xFFFFC978);
  static const cream = Color(0xFFFFF8F1);
  static const ink = Color(0xFF2B1C19);
  static const plum = Color(0xFF6D597A);
  static const sage = Color(0xFF7FA88F);
  static const sky = Color(0xFF5B7DB1);

  static const darkTomato = Color(0xFFFF7A59);
  static const darkCoral = Color(0xFFFFA27F);

  static const _tagColors = <String, Color>{
    '学习': Color(0xFFE85B3C),
    '工作': Color(0xFF5B7DB1),
    '生活': Color(0xFF6FA88A),
    '阅读': Color(0xFFA98467),
    '运动': Color(0xFFE09F3E),
  };

  static Color tag(String tag) {
    final known = _tagColors[tag];
    if (known != null) return known;
    if (tag.trim().isEmpty) return tomato;
    final hash = tag.runes.fold<int>(
      0,
      (sum, rune) => (sum * 31 + rune) & 0x7fffffff,
    );
    const palette = <Color>[
      tomato,
      sky,
      sage,
      Color(0xFFA98467),
      Color(0xFFE09F3E),
      plum,
      Color(0xFF4F9478),
      Color(0xFFB06A8E),
    ];
    return palette[hash % palette.length];
  }

  static Color tagSoft(String tag, Brightness brightness) {
    final base = AppPalette.tag(tag);
    return brightness == Brightness.dark
        ? base.withValues(alpha: 0.20)
        : base.withValues(alpha: 0.11);
  }
}

/// 每个主题独有的表面颜色，用来做渐变背景、玻璃卡片和弱化文字。
@immutable
class AppSurfaceColors extends ThemeExtension<AppSurfaceColors> {
  const AppSurfaceColors({
    required this.canvasTop,
    required this.canvasBottom,
    required this.card,
    required this.cardMuted,
    required this.border,
    required this.muted,
    required this.faint,
    required this.glow,
    required this.track,
    required this.nav,
    required this.sheet,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color canvasTop;
  final Color canvasBottom;
  final Color card;
  final Color cardMuted;
  final Color border;
  final Color muted;
  final Color faint;
  final Color glow;
  final Color track;
  final Color nav;
  final Color sheet;
  final Color heroStart;
  final Color heroEnd;

  static const light = AppSurfaceColors(
    canvasTop: Color(0xFFFFF9F3),
    canvasBottom: Color(0xFFFDEADF),
    card: Color(0xFFFEFCFA),
    cardMuted: Color(0xFFFFF3EA),
    border: Color(0xFFF0D9CC),
    muted: Color(0xFF8A7368),
    faint: Color(0xFFC7B1A5),
    glow: Color(0xFFFF9A6E),
    track: Color(0xFFF4DFD4),
    nav: Color(0xFFFFFBF7),
    sheet: Color(0xFFFFFBF7),
    heroStart: Color(0xFF3B2335),
    heroEnd: Color(0xFF7A3A34),
  );

  static const dark = AppSurfaceColors(
    canvasTop: Color(0xFF171014),
    canvasBottom: Color(0xFF251712),
    card: Color(0xFF241A18),
    cardMuted: Color(0xFF2E211D),
    border: Color(0xFF3B2B26),
    muted: Color(0xFFB09A8F),
    faint: Color(0xFF765F56),
    glow: Color(0xFFFF7D57),
    track: Color(0xFF382722),
    nav: Color(0xFF211715),
    sheet: Color(0xFF211715),
    heroStart: Color(0xFF3B2335),
    heroEnd: Color(0xFF823F37),
  );

  @override
  AppSurfaceColors copyWith({
    Color? canvasTop,
    Color? canvasBottom,
    Color? card,
    Color? cardMuted,
    Color? border,
    Color? muted,
    Color? faint,
    Color? glow,
    Color? track,
    Color? nav,
    Color? sheet,
    Color? heroStart,
    Color? heroEnd,
  }) {
    return AppSurfaceColors(
      canvasTop: canvasTop ?? this.canvasTop,
      canvasBottom: canvasBottom ?? this.canvasBottom,
      card: card ?? this.card,
      cardMuted: cardMuted ?? this.cardMuted,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      glow: glow ?? this.glow,
      track: track ?? this.track,
      nav: nav ?? this.nav,
      sheet: sheet ?? this.sheet,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
    );
  }

  @override
  AppSurfaceColors lerp(
    covariant ThemeExtension<AppSurfaceColors>? other,
    double t,
  ) {
    if (other is! AppSurfaceColors) return this;
    return AppSurfaceColors(
      canvasTop: Color.lerp(canvasTop, other.canvasTop, t)!,
      canvasBottom: Color.lerp(canvasBottom, other.canvasBottom, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardMuted: Color.lerp(cardMuted, other.cardMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      track: Color.lerp(track, other.track, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSurfaceColors get surfaces =>
      Theme.of(this).extension<AppSurfaceColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get primary => Theme.of(this).colorScheme.primary;

  Color get onSurface => Theme.of(this).colorScheme.onSurface;

  TextStyle get timerTextStyle => TextStyle(
    fontSize: 58,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: onSurface,
  );
}

abstract final class AppTheme {
  /// golden 截图测试使用的备用字体。生产环境保持 null，沿用系统字体。
  static String? debugFontFamily;

  /// 与 [debugFontFamily] 搭配的拉丁/标点回退字体，仅用于截图测试。
  static String? debugFontFallback;

  static const _fontFallback = <String>[
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Microsoft YaHei',
    'Droid Sans Fallback',
  ];

  static const _serifFallback = <String>[
    'Songti SC',
    'Noto Serif CJK SC',
    'Noto Serif SC',
    'SimSun',
    'Droid Sans Fallback',
  ];

  static final light = _build(
    brightness: Brightness.light,
    scheme:
        ColorScheme.fromSeed(
          seedColor: AppPalette.tomato,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppPalette.tomato,
          onPrimary: Colors.white,
          secondary: AppPalette.apricot,
          onSecondary: AppPalette.ink,
          tertiary: AppPalette.plum,
          surface: const Color(0xFFFEFCFA),
          onSurface: AppPalette.ink,
          surfaceContainerHighest: const Color(0xFFFFF1E7),
          outline: const Color(0xFFD8BEB0),
          outlineVariant: const Color(0xFFF0D9CC),
        ),
    surfaces: AppSurfaceColors.light,
  );

  static final dark = _build(
    brightness: Brightness.dark,
    scheme:
        ColorScheme.fromSeed(
          seedColor: AppPalette.darkTomato,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppPalette.darkTomato,
          onPrimary: const Color(0xFF2A110B),
          secondary: AppPalette.darkCoral,
          onSecondary: const Color(0xFF2A110B),
          tertiary: const Color(0xFFC7B3E6),
          surface: const Color(0xFF241A18),
          onSurface: const Color(0xFFF6ECE6),
          surfaceContainerHighest: const Color(0xFF33241F),
          outline: const Color(0xFF6E564C),
          outlineVariant: const Color(0xFF3B2B26),
        ),
    surfaces: AppSurfaceColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required AppSurfaceColors surfaces,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: debugFontFamily,
    );
    final fontFallback = debugFontFallback == null
        ? _fontFallback
        : <String>[debugFontFallback!, ..._fontFallback];
    final serifFallback = debugFontFallback == null
        ? _serifFallback
        : <String>[debugFontFallback!, ..._serifFallback];
    final textTheme = base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamilyFallback: fontFallback,
        )
        .copyWith(
          displayLarge: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 54,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: scheme.onSurface,
          ),
          displayMedium: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 40,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          displaySmall: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 32,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          headlineLarge: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 30,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          headlineSmall: TextStyle(
            fontFamily: debugFontFamily ?? 'serif',
            fontFamilyFallback: serifFallback,
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: surfaces.muted,
          ),
          labelLarge: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: scheme.onSurface,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: surfaces.muted,
          ),
        );

    final effectiveTextTheme = debugFontFamily == null
        ? textTheme
        : textTheme.apply(fontFamily: debugFontFamily);

    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: surfaces.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: surfaces.canvasTop,
      textTheme: effectiveTextTheme,
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: _fontFallback,
      ),
      extensions: <ThemeExtension<dynamic>>[surfaces],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(
        color: surfaces.border.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: surfaces.border),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaces.cardMuted.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: surfaces.faint, fontSize: 15),
        border: roundedBorder,
        enabledBorder: roundedBorder.copyWith(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: roundedBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: roundedBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: roundedBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFFF3E7E0)
            : const Color(0xFF2B1C19),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF2B1C19)
              : const Color(0xFFFFF8F1),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaces.sheet,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaces.sheet,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        showDragHandle: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return surfaces.faint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return surfaces.track;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: surfaces.track,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaces.track,
        circularTrackColor: surfaces.track,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFFF3E7E0)
              : const Color(0xFF2B1C19),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF2B1C19)
              : const Color(0xFFFFF8F1),
          fontSize: 12,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaces.sheet,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
