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
    final overlayTop = surfaces.canvasTop.withValues(
      alpha: context.isDark ? 0.55 : 0.58,
    );
    final overlayBottom = surfaces.canvasBottom.withValues(
      alpha: context.isDark ? 0.62 : 0.66,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // 先用不透明渐变铺满整个视口，避免滚动到底部时露出白色断层。
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [surfaces.canvasTop, surfaces.canvasBottom],
            ),
          ),
        ),
        Image.asset(
          'assets/images/sunset_ocean.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.low,
          opacity: const AlwaysStoppedAnimation<double>(0.32),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [overlayTop, overlayBottom],
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
