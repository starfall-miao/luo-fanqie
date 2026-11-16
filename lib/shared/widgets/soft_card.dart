import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../features/settings/providers/settings_controller.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 18,
    this.color,
    this.gradient,
    this.border,
    this.onTap,
    this.onLongPress,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final glass = context.select<SettingsController, bool>(
      (controller) => controller.settings.glassEffects,
    );
    final borderRadius = BorderRadius.circular(radius);
    final baseColor = color ?? surfaces.card;
    final cardColor = glass
        ? baseColor.withValues(alpha: context.isDark ? 0.78 : 0.82)
        : Color.alphaBlend(
            baseColor.withValues(alpha: context.isDark ? 0.92 : 0.9),
            surfaces.canvasTop,
          );
    final decoration = BoxDecoration(
      color: gradient == null ? cardColor : null,
      gradient: gradient,
      borderRadius: borderRadius,
      border: border ?? Border.all(color: surfaces.border),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.2 : 0.04,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
    final content = Padding(padding: padding, child: child);
    Widget surface = Material(
      type: MaterialType.transparency,
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
    if (glass) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: surface,
      );
    }
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: decoration,
        child: ClipRRect(borderRadius: borderRadius, child: surface),
      ),
    );
  }
}
