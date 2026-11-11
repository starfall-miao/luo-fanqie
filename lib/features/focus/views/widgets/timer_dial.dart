import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../timer/models/pomodoro_phase.dart';
import '../../../timer/theme/phase_style.dart';

class TimerDial extends StatelessWidget {
  const TimerDial({
    super.key,
    required this.phase,
    required this.status,
    required this.progress,
    required this.remainingLabel,
    required this.roundNumber,
    required this.rounds,
    required this.completedInCycle,
    required this.taskTitle,
    this.maxSize = 318,
  });

  final PomodoroPhase phase;
  final PomodoroStatus status;
  final double progress;
  final String remainingLabel;
  final int roundNumber;
  final int rounds;
  final int completedInCycle;
  final String? taskTitle;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final visuals = visualsFor(phase);
    final size = math.min(MediaQuery.sizeOf(context).width - 64, maxSize);
    final timeSize = size * 0.185;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                builder: (context, value, child) => CustomPaint(
                  painter: _DialPainter(
                    progress: value,
                    phase: phase,
                    trackColor: surfaces.track,
                    tickColor: surfaces.border.withValues(alpha: 0.75),
                    surfaceColor: surfaces.card.withValues(
                      alpha: context.isDark ? 0.42 : 0.52,
                    ),
                    borderColor: surfaces.border.withValues(alpha: 0.7),
                    isDark: context.isDark,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PhaseBadge(phase: phase, status: status),
                  SizedBox(height: size * 0.045),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      remainingLabel,
                      style: TextStyle(
                        fontSize: timeSize,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: context.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _RoundDots(
                    rounds: rounds,
                    completed: completedInCycle,
                    accent: visuals.accent,
                    idle: status == PomodoroStatus.idle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    taskTitle ?? phase.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: surfaces.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (phase == PomodoroPhase.focus) ...[
                    const SizedBox(height: 3),
                    Text(
                      '第 $roundNumber 颗 / 共 $rounds 颗',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: surfaces.faint,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase, required this.status});

  final PomodoroPhase phase;
  final PomodoroStatus status;

  @override
  Widget build(BuildContext context) {
    final visuals = visualsFor(phase);
    final label = switch (status) {
      PomodoroStatus.running => phase == PomodoroPhase.focus ? '专注中' : '休息中',
      PomodoroStatus.paused => '已暂停',
      PomodoroStatus.idle => phase == PomodoroPhase.focus ? '准备专注' : '休息一下',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visuals.accent.withValues(alpha: context.isDark ? 0.22 : 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: visuals.accent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.2,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: visuals.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundDots extends StatelessWidget {
  const _RoundDots({
    required this.rounds,
    required this.completed,
    required this.accent,
    required this.idle,
  });

  final int rounds;
  final int completed;
  final Color accent;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rounds; i += 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i < completed ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: i < completed
                  ? accent
                  : (i == completed && !idle
                        ? accent.withValues(alpha: 0.45)
                        : surfaces.faint.withValues(alpha: 0.5)),
            ),
          ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.phase,
    required this.trackColor,
    required this.tickColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDark,
  });

  final double progress;
  final PomodoroPhase phase;
  final Color trackColor;
  final Color tickColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 4;
    final ringRadius = outerRadius - 22;
    final ringWidth = size.width * 0.045;
    final visuals = visualsFor(phase);
    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    // 表盘底部的一层薄雾。
    final discPaint = Paint()
      ..shader = RadialGradient(
        colors: [surfaceColor, surfaceColor.withValues(alpha: 0)],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawCircle(center, outerRadius, discPaint);
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 60 格刻度：经过的刻度会被点亮。
    for (var i = 0; i < 60; i += 1) {
      final angle = -math.pi / 2 + (2 * math.pi * i / 60);
      final isMajor = i % 5 == 0;
      final active = i / 60 <= progress + 0.0001;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * (outerRadius - 9);
      final end =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (outerRadius - (isMajor ? 1.5 : 4));
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = active
              ? visuals.accent.withValues(alpha: isDark ? 0.75 : 0.55)
              : tickColor.withValues(alpha: isMajor ? 0.9 : 0.55)
          ..strokeWidth = isMajor ? 1.7 : 1.1
          ..strokeCap = StrokeCap.round,
      );
    }

    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas.drawArc(
      ringRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) {
      _drawTomatoDot(
        canvas,
        center + Offset(0, -ringRadius),
        visuals.accent,
        ringWidth,
      );
      return;
    }

    final sweep = math.pi * 2 * progress;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [...visuals.gradient, visuals.gradient.first],
        stops: const [0, 0.45, 0.75, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    final startAngle = -math.pi / 2;

    // 光晕让进度像落日余晖。
    canvas.drawArc(
      ringRect,
      startAngle,
      sweep,
      false,
      Paint()
        ..color = visuals.accent.withValues(alpha: isDark ? 0.38 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth * 1.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawArc(ringRect, startAngle, sweep, false, arcPaint);

    final endAngle = startAngle + sweep;
    final endPoint =
        center + Offset(math.cos(endAngle), math.sin(endAngle)) * ringRadius;
    _drawTomatoDot(canvas, endPoint, visuals.accent, ringWidth);
  }

  void _drawTomatoDot(
    Canvas canvas,
    Offset position,
    Color accent,
    double ringWidth,
  ) {
    final dotRadius = ringWidth * 0.66;
    canvas.drawCircle(
      position,
      dotRadius + 4,
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      position,
      dotRadius + 1.5,
      Paint()
        ..color = isDark ? const Color(0xFF241A18) : const Color(0xFFFFFBF7),
    );
    canvas.drawCircle(position, dotRadius, Paint()..color = accent);
    canvas.drawCircle(
      position + Offset(-dotRadius * 0.28, -dotRadius * 0.28),
      dotRadius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.isDark != isDark ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.surfaceColor != surfaceColor;
}
