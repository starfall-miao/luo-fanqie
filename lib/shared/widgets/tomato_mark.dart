import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 落·番茄的品牌图形：一颗带着叶子的落日番茄。
class TomatoMark extends StatelessWidget {
  const TomatoMark({
    super.key,
    this.size = 34,
    this.bodyColor = AppPalette.tomato,
    this.leafColor = AppPalette.sage,
    this.withGlow = false,
  });

  final double size;
  final Color bodyColor;
  final Color leafColor;
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TomatoPainter(
          bodyColor: bodyColor,
          leafColor: leafColor,
          withGlow: withGlow,
        ),
      ),
    );
  }
}

class _TomatoPainter extends CustomPainter {
  const _TomatoPainter({
    required this.bodyColor,
    required this.leafColor,
    required this.withGlow,
  });

  final Color bodyColor;
  final Color leafColor;
  final bool withGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.58);
    final radius = size.width * 0.33;
    final bodyRect = Rect.fromCircle(center: center, radius: radius);

    if (withGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            bodyColor.withValues(alpha: 0.36),
            bodyColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2));
      canvas.drawCircle(center, radius * 2, glowPaint);
    }

    // 主体：日落的暖红到番茄橙。
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7E5D), AppPalette.tomato, Color(0xFFCE4129)],
      ).createShader(bodyRect);
    final body = Path()
      ..addOval(bodyRect)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // 左上角柔光。
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx - radius * 0.34, center.dy - radius * 0.42);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.55,
        height: radius * 0.3,
      ),
      highlight,
    );
    canvas.restore();

    // 五片叶子。
    final leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;
    final stemTop = Offset(center.dx, center.dy - radius * 0.93);
    for (var i = 0; i < 5; i += 1) {
      final angle = -math.pi / 2 + (i - 2) * 0.52;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final side = Offset(-direction.dy, direction.dx);
      final tip =
          stemTop + direction * radius * 0.52 + Offset(0, radius * 0.08);
      final path = Path()
        ..moveTo(stemTop.dx, stemTop.dy)
        ..quadraticBezierTo(
          (stemTop.dx + tip.dx) / 2 + side.dx * radius * 0.18,
          (stemTop.dy + tip.dy) / 2 + side.dy * radius * 0.18,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (stemTop.dx + tip.dx) / 2 - side.dx * radius * 0.12,
          (stemTop.dy + tip.dy) / 2 - side.dy * radius * 0.12,
          stemTop.dx,
          stemTop.dy,
        )
        ..close();
      canvas.drawPath(path, leafPaint);
    }

    // 果蒂。
    final stemPaint = Paint()
      ..color = leafColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(center.dx, center.dy - radius * 0.9)
      ..quadraticBezierTo(
        center.dx + radius * 0.08,
        center.dy - radius * 1.22,
        center.dx + radius * 0.28,
        center.dy - radius * 1.25,
      );
    canvas.drawPath(stemPath, stemPaint);
  }

  @override
  bool shouldRepaint(covariant _TomatoPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.leafColor != leafColor ||
      oldDelegate.withGlow != withGlow;
}
