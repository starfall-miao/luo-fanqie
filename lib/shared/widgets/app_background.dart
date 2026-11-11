import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 全局暖色渐变背景，叠上两团柔和的落日辉光。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaces.canvasTop, surfaces.canvasBottom],
            ),
          ),
        ),
        Positioned(
          top: -160,
          right: -120,
          child: _Glow(
            size: 420,
            color: scheme.primary.withValues(alpha: 0.20),
          ),
        ),
        Positioned(
          top: 180,
          left: -170,
          child: _Glow(
            size: 380,
            color: AppPalette.apricot.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -180,
          right: -80,
          child: _Glow(
            size: 380,
            color: AppPalette.plum.withValues(alpha: 0.10),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
