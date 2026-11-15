import 'package:flutter/material.dart';

import '../models/weather_snapshot.dart';

/// 本地绘制的天气场景：天气数据来自网络，画面不依赖版权图片，
/// 上次天气会缓存，离线时仍能渲染。
class WeatherScene extends StatelessWidget {
  const WeatherScene({super.key, required this.snapshot});

  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _baseColor(context),
      child: CustomPaint(
        painter: _WeatherPainter(snapshot),
        child: const SizedBox.expand(),
      ),
    );
  }

  Color _baseColor(BuildContext context) {
    final dark =
        snapshot.isDay == false ||
        Theme.of(context).brightness == Brightness.dark;
    return switch (snapshot.condition) {
      WeatherCondition.clear =>
        dark ? const Color(0xFF171528) : const Color(0xFFFFE2BE),
      WeatherCondition.partlyCloudy =>
        dark ? const Color(0xFF1E2030) : const Color(0xFFFFEAD5),
      WeatherCondition.cloudy =>
        dark ? const Color(0xFF252A35) : const Color(0xFFDCE4EC),
      WeatherCondition.rain =>
        dark ? const Color(0xFF152431) : const Color(0xFFB8CCDD),
      WeatherCondition.thunder => const Color(0xFF252338),
      WeatherCondition.snow =>
        dark ? const Color(0xFF202833) : const Color(0xFFEFF6FA),
      WeatherCondition.fog =>
        dark ? const Color(0xFF313239) : const Color(0xFFE6E5E3),
    };
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.snapshot);

  final WeatherSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = _gradientColors();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    if (!snapshot.isDay) {
      _paintStars(canvas, size);
    } else if (snapshot.condition == WeatherCondition.clear ||
        snapshot.condition == WeatherCondition.partlyCloudy) {
      _paintSun(canvas, size);
    }
    if (snapshot.condition == WeatherCondition.cloudy ||
        snapshot.condition == WeatherCondition.partlyCloudy ||
        snapshot.condition == WeatherCondition.rain ||
        snapshot.condition == WeatherCondition.thunder ||
        snapshot.condition == WeatherCondition.fog) {
      _paintClouds(canvas, size);
    }
    if (snapshot.condition == WeatherCondition.rain ||
        snapshot.condition == WeatherCondition.thunder) {
      _paintRain(canvas, size);
    }
    if (snapshot.condition == WeatherCondition.snow) {
      _paintSnow(canvas, size);
    }
  }

  List<Color> _gradientColors() {
    final dark = !snapshot.isDay;
    return switch (snapshot.condition) {
      WeatherCondition.clear =>
        dark
            ? const [Color(0xFF171528), Color(0xFF382B42)]
            : const [Color(0xFFFFE8CA), Color(0xFFFFB98D)],
      WeatherCondition.partlyCloudy =>
        dark
            ? const [Color(0xFF1D2030), Color(0xFF44445A)]
            : const [Color(0xFFFFEEDB), Color(0xFFF3C7A6)],
      WeatherCondition.cloudy =>
        dark
            ? const [Color(0xFF262A33), Color(0xFF5C6065)]
            : const [Color(0xFFEAF0F4), Color(0xFFB8C4CC)],
      WeatherCondition.rain =>
        dark
            ? const [Color(0xFF10202C), Color(0xFF334C58)]
            : const [Color(0xFFD5E5EF), Color(0xFF8FA9BA)],
      WeatherCondition.thunder => const [Color(0xFF1B1B2A), Color(0xFF51536C)],
      WeatherCondition.snow =>
        dark
            ? const [Color(0xFF1B2631), Color(0xFF556B7A)]
            : const [Color(0xFFF5FBFF), Color(0xFFC4D7E0)],
      WeatherCondition.fog =>
        dark
            ? const [Color(0xFF2A2B31), Color(0xFF53545A)]
            : const [Color(0xFFF0EFEC), Color(0xFFC5C6C5)],
    };
  }

  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.18);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFF2C9).withValues(alpha: 0.7),
              const Color(0xFFFFF2C9).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.18),
          );
    canvas.drawCircle(center, size.width * 0.18, glow);
    canvas.drawCircle(
      center,
      size.width * 0.035,
      Paint()..color = const Color(0xFFFFE8A8),
    );
  }

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 24; i += 1) {
      final x = (i * 73.0) % size.width;
      final y = (i * 47.0) % (size.height * 0.42);
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : 0.8, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.26);
    for (var i = 0; i < 4; i += 1) {
      final cx = size.width * (0.18 + i * 0.22);
      final cy = size.height * (0.12 + (i % 2) * 0.08);
      final w = size.width * 0.2;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: w, height: w * 0.28),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + w * 0.2, cy - w * 0.1),
          width: w * 0.7,
          height: w * 0.3,
        ),
        paint,
      );
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5F2FF).withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i += 1) {
      final x = (i * 91.0) % size.width;
      final y = (i * 137.0) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 26), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 30; i += 1) {
      final x = (i * 61.0) % size.width;
      final y = (i * 97.0) % size.height;
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}
