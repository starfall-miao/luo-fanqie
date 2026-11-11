import 'package:flutter/material.dart';

import '../models/pomodoro_phase.dart';

class PhaseVisuals {
  const PhaseVisuals({
    required this.gradient,
    required this.accent,
    required this.icon,
  });

  final List<Color> gradient;
  final Color accent;
  final IconData icon;
}

PhaseVisuals visualsFor(PomodoroPhase phase) => switch (phase) {
  PomodoroPhase.focus => const PhaseVisuals(
    gradient: [Color(0xFFFF7A59), Color(0xFFF4A261), Color(0xFFFFC978)],
    accent: Color(0xFFE85B3C),
    icon: Icons.local_fire_department_rounded,
  ),
  PomodoroPhase.shortBreak => const PhaseVisuals(
    gradient: [Color(0xFF5BA184), Color(0xFF8FC9A8), Color(0xFFD8E9C4)],
    accent: Color(0xFF4F9478),
    icon: Icons.eco_rounded,
  ),
  PomodoroPhase.longBreak => const PhaseVisuals(
    gradient: [Color(0xFF6D5A95), Color(0xFF9F86C7), Color(0xFFD8C0E6)],
    accent: Color(0xFF7D68A8),
    icon: Icons.nights_stay_rounded,
  ),
};
