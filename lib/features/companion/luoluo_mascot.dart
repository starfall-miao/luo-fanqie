import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 落落：一只会陪专注的猫娘。
///
/// 全部用 CustomPainter 绘制，不依赖图片素材，也不会在缩放时变糊。
class LuoLuoMascot extends StatefulWidget {
  const LuoLuoMascot({
    super.key,
    this.size = 140,
    this.studying = false,
    this.happy = false,
  });

  final double size;
  final bool studying;
  final bool happy;

  @override
  State<LuoLuoMascot> createState() => _LuoLuoMascotState();
}

class _LuoLuoMascotState extends State<LuoLuoMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  Timer? _blinkTimer;
  Timer? _blinkCloseTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 5000), (_) {
      if (!mounted) return;
      setState(() => _blinking = true);
      _blinkCloseTimer?.cancel();
      _blinkCloseTimer = Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _blinking = false);
      });
    });
  }

  @override
  void didUpdateWidget(covariant LuoLuoMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studying != widget.studying ||
        oldWidget.happy != widget.happy) {
      _breath.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkCloseTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LuoLuoPainter(
            phase: _breath.value,
            blinking: _blinking,
            studying: widget.studying,
            happy: widget.happy,
          ),
        ),
      ),
    );
  }
}

class _LuoLuoPainter extends CustomPainter {
  _LuoLuoPainter({
    required this.phase,
    required this.blinking,
    required this.studying,
    required this.happy,
  });

  final double phase;
  final bool blinking;
  final bool studying;
  final bool happy;

  static const _hair = Color(0xFF6A493F);
  static const _hairDeep = Color(0xFF53362F);
  static const _skin = Color(0xFFFFE5D3);
  static const _skinShade = Color(0xFFF5CBB8);
  static const _earInner = Color(0xFFF3A79E);
  static const _dress = Color(0xFFFFF6EA);
  static const _dressShade = Color(0xFFF5E4D4);
  static const _eye = Color(0xFF4A2C26);
  static const _eyeWarm = Color(0xFFB9683F);
  static const _book = Color(0xFFFFFBF2);
  static const _bookLine = Color(0xFFD9B9A6);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    canvas.save();
    canvas.scale(scale);
    final breathe = 1 + math.sin(phase * math.pi) * 0.008;
    canvas.translate(0, 100);
    canvas.scale(1.0, breathe);
    canvas.translate(0, -100);

    _paintTail(canvas);
    _paintBody(canvas);
    _paintHead(canvas);

    if (studying) {
      _paintBook(canvas);
    } else {
      _paintPaws(canvas);
    }
    canvas.restore();
  }

  void _paintTail(Canvas canvas) {
    final sway = math.sin(phase * math.pi * 2) * 8;
    final path = Path()
      ..moveTo(146, 153)
      ..cubicTo(180, 158, 184, 126 + sway, 168, 112 + sway)
      ..cubicTo(160, 105 + sway, 153, 116 + sway, 160, 122 + sway);
    canvas.drawPath(
      path,
      Paint()
        ..color = _hairDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBody(Canvas canvas) {
    final dressPath = Path()
      ..moveTo(72, 126)
      ..cubicTo(58, 130, 54, 151, 56, 176)
      ..cubicTo(60, 194, 66, 198, 100, 198)
      ..cubicTo(134, 198, 140, 194, 144, 176)
      ..cubicTo(146, 151, 142, 130, 128, 126)
      ..close();
    canvas.drawPath(
      dressPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_dress, _dressShade],
        ).createShader(const Rect.fromLTWH(54, 126, 92, 72)),
    );
    // 领口的红色小蝴蝶结
    canvas.drawCircle(
      const Offset(100, 132),
      4.6,
      Paint()..color = AppPalette.tomato,
    );
    final ribbon = Path()
      ..moveTo(100, 133)
      ..lineTo(89, 126)
      ..lineTo(90, 140)
      ..close()
      ..moveTo(100, 133)
      ..lineTo(111, 126)
      ..lineTo(110, 140)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = AppPalette.tomato);
    canvas.drawCircle(
      const Offset(100, 133),
      2.2,
      Paint()..color = AppPalette.tomatoDeep,
    );
    // 裙摆的柔和褶皱
    final fold = Paint()
      ..color = _dressShade.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final x in [75.0, 92.0, 108.0, 125.0]) {
      canvas.drawLine(Offset(x, 158), Offset(x + (x - 100) * 0.06, 193), fold);
    }
  }

  void _paintHead(Canvas canvas) {
    // 后面的头发
    canvas.drawOval(
      const Rect.fromLTWH(55, 40, 90, 104),
      Paint()..color = _hairDeep,
    );
    // 耳朵
    _paintEar(canvas, const Offset(74, 55), -0.30);
    _paintEar(canvas, const Offset(126, 55), 0.30);
    // 脸
    canvas.drawOval(
      const Rect.fromLTWH(62, 53, 76, 78),
      Paint()..color = _skin,
    );
    canvas.drawOval(
      const Rect.fromLTWH(68, 105, 64, 24),
      Paint()..color = _skinShade.withValues(alpha: 0.22),
    );
    // 刘海
    final bangs = Path()
      ..moveTo(61, 78)
      ..cubicTo(62, 53, 81, 43, 100, 43)
      ..cubicTo(121, 43, 139, 54, 139, 79)
      ..cubicTo(131, 71, 124, 68, 117, 74)
      ..cubicTo(111, 64, 102, 65, 97, 75)
      ..cubicTo(90, 65, 83, 66, 77, 76)
      ..cubicTo(71, 69, 66, 72, 61, 78)
      ..close();
    canvas.drawPath(bangs, Paint()..color = _hair);
    // 侧发
    final side = Paint()..color = _hair;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 76, 15, 62),
        const Radius.circular(8),
      ),
      side,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(130, 76, 15, 62),
        const Radius.circular(8),
      ),
      side,
    );
    // 番茄发夹
    canvas.drawCircle(
      const Offset(134, 64),
      6,
      Paint()..color = AppPalette.tomato,
    );
    canvas.drawPath(
      Path()
        ..moveTo(131, 59)
        ..quadraticBezierTo(134, 54, 138, 57)
        ..quadraticBezierTo(135, 61, 131, 59),
      Paint()..color = AppPalette.sage,
    );
    // 眼睛
    _paintEye(canvas, const Offset(84, 88));
    _paintEye(canvas, const Offset(116, 88));
    // 腮红
    canvas.drawOval(
      const Rect.fromLTWH(69, 100, 16, 7),
      Paint()..color = _earInner.withValues(alpha: 0.45),
    );
    canvas.drawOval(
      const Rect.fromLTWH(115, 100, 16, 7),
      Paint()..color = _earInner.withValues(alpha: 0.45),
    );
    // 嘴巴
    final mouth = Path();
    if (happy) {
      mouth
        ..moveTo(94, 108)
        ..quadraticBezierTo(100, 116, 106, 108);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      mouth
        ..moveTo(96, 109)
        ..quadraticBezierTo(100, 112, 104, 109);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintEar(Canvas canvas, Offset base, double tilt) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final outer = Path()
      ..moveTo(-14, 8)
      ..lineTo(-4, -26)
      ..lineTo(16, 6)
      ..close();
    canvas.drawPath(outer, Paint()..color = _hairDeep);
    final inner = Path()
      ..moveTo(-6, 4)
      ..lineTo(-2, -17)
      ..lineTo(8, 2)
      ..close();
    canvas.drawPath(inner, Paint()..color = _earInner);
    canvas.restore();
  }

  void _paintEye(Canvas canvas, Offset center) {
    if (blinking) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 15, height: 8),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 12.5, height: 15),
      Paint()..color = _eye,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 3.5), width: 8, height: 8),
      Paint()..color = _eyeWarm,
    );
    canvas.drawCircle(
      center.translate(-3.6, -4.4),
      2.2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center.translate(2.8, 4.2),
      1.1,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _paintBook(Canvas canvas) {
    // 手臂
    final arm = Paint()
      ..color = _skin
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(77, 148), const Offset(86, 169), arm);
    canvas.drawLine(const Offset(123, 148), const Offset(114, 169), arm);
    // 打开的书
    final left = Path()
      ..moveTo(58, 166)
      ..quadraticBezierTo(78, 158, 100, 166)
      ..lineTo(100, 191)
      ..quadraticBezierTo(78, 183, 58, 189)
      ..close();
    final right = Path()
      ..moveTo(142, 166)
      ..quadraticBezierTo(122, 158, 100, 166)
      ..lineTo(100, 191)
      ..quadraticBezierTo(122, 183, 142, 189)
      ..close();
    canvas.drawPath(left, Paint()..color = _book);
    canvas.drawPath(right, Paint()..color = _book);
    final outline = Paint()
      ..color = _bookLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(left, outline);
    canvas.drawPath(right, outline);
    canvas.drawLine(const Offset(100, 166), const Offset(100, 191), outline);
    for (final y in [172.0, 178.0, 184.0]) {
      canvas.drawLine(Offset(66, y), Offset(94, y + 2), outline);
      canvas.drawLine(Offset(106, y + 2), Offset(134, y), outline);
    }
    // 搭在书上的小爪爪
    canvas.drawOval(
      const Rect.fromLTWH(80, 170, 12, 9),
      Paint()..color = _skin,
    );
    canvas.drawOval(
      const Rect.fromLTWH(108, 170, 12, 9),
      Paint()..color = _skin,
    );
  }

  void _paintPaws(Canvas canvas) {
    final paw = Paint()..color = _skin;
    canvas.drawOval(const Rect.fromLTWH(69, 151, 17, 22), paw);
    canvas.drawOval(const Rect.fromLTWH(114, 151, 17, 22), paw);
    final line = Paint()
      ..color = _skinShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawArc(
      const Rect.fromLTWH(73, 153, 9, 8),
      0.1,
      math.pi * 0.9,
      false,
      line,
    );
    canvas.drawArc(
      const Rect.fromLTWH(118, 153, 9, 8),
      0.1,
      math.pi * 0.9,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _LuoLuoPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.blinking != blinking ||
        oldDelegate.studying != studying ||
        oldDelegate.happy != happy;
  }
}
