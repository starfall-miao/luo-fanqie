enum PomodoroPhase { focus, shortBreak, longBreak }

enum PomodoroStatus { idle, running, paused }

extension PomodoroPhaseX on PomodoroPhase {
  String get label => switch (this) {
    PomodoroPhase.focus => '专注',
    PomodoroPhase.shortBreak => '小憩',
    PomodoroPhase.longBreak => '长休息',
  };

  String get subtitle => switch (this) {
    PomodoroPhase.focus => '保持专注，番茄正在生长',
    PomodoroPhase.shortBreak => '起身走走，喝口水',
    PomodoroPhase.longBreak => '好好休息，看看远处',
  };

  bool get isBreak => this != PomodoroPhase.focus;
}
