import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
    this.color,
    this.gradient,
    this.border,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final borderRadius = BorderRadius.circular(radius);
    final baseColor = color ?? surfaces.card;
    final glassColor = baseColor.withValues(
      alpha: context.isDark ? 0.78 : 0.82,
    );
    final decoration = BoxDecoration(
      color: gradient == null ? glassColor : null,
      gradient: gradient,
      borderRadius: borderRadius,
      border:
          border ?? Border.all(color: surfaces.border.withValues(alpha: 0.8)),
      boxShadow: shadow && !context.isDark
          ? [
              BoxShadow(
                color: const Color(0xFF7A3A2A).withValues(alpha: 0.055),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ]
          : null,
    );
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            type: MaterialType.transparency,
            child: onTap == null
                ? content
                : InkWell(onTap: onTap, child: content),
          ),
        ),
      ),
    );
  }
}
