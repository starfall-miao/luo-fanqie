import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'luoluo_mascot.dart';

class LuoLuoCompanion extends StatelessWidget {
  const LuoLuoCompanion({
    super.key,
    required this.message,
    this.mascotSize = 120,
    this.compact = false,
    this.studying = false,
    this.happy = false,
  });

  final String message;
  final double mascotSize;
  final bool compact;
  final bool studying;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    final mascot = LuoLuoMascot(
      size: mascotSize,
      studying: studying,
      happy: happy,
    );
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: context.surfaces.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.surfaces.border.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '落落',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppPalette.tomato,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: context.onSurface,
            ),
          ),
        ],
      ),
    );
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mascot,
          const SizedBox(width: 10),
          Expanded(child: bubble),
        ],
      );
    }
    return Column(children: [mascot, const SizedBox(height: 4), bubble]);
  }
}
