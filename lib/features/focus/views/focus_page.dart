import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/providers/stats_controller.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_controller.dart';
import '../../timer/models/pomodoro_phase.dart';
import '../../timer/providers/pomodoro_controller.dart';
import '../../timer/theme/phase_style.dart';
import 'session_page.dart';
import 'widgets/task_picker_sheet.dart';
import 'widgets/timer_dial.dart';

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<PomodoroController>();
    final tasks = context.watch<TaskController>();
    final stats = context.watch<StatsController>();
    final settings = context.watch<SettingsController>().settings;
    final now = DateTime.now();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialMax = screenHeight < 720
        ? 238.0
        : screenHeight < 800
        ? 264.0
        : screenHeight < 900
        ? 294.0
        : 318.0;
    final selected = tasks.taskById(timer.selectedTaskId);
    final goalProgress = settings.dailyGoalMinutes == 0
        ? 0.0
        : stats.todayMinutes / settings.dailyGoalMinutes;

    final phaseSwitch = _PhaseSwitch(timer: timer);
    final dial = TimerDial(
      phase: timer.phase,
      status: timer.status,
      progress: timer.progress,
      remainingLabel: timer.remainingLabel,
      roundNumber: timer.roundNumber,
      rounds: settings.roundsPerLongBreak,
      completedInCycle: timer.completedInCycle,
      taskTitle: selected?.title,
      maxSize: dialMax,
    );
    final wideDial = TimerDial(
      phase: timer.phase,
      status: timer.status,
      progress: timer.progress,
      remainingLabel: timer.remainingLabel,
      roundNumber: timer.roundNumber,
      rounds: settings.roundsPerLongBreak,
      completedInCycle: timer.completedInCycle,
      taskTitle: selected?.title,
      maxSize: math.min(360, screenHeight * 0.46),
    );
    final controls = _TimerControls(timer: timer);
    final taskCard = _FocusTaskCard(timer: timer, task: selected);
    final goalCard = _GoalCard(
      todayMinutes: stats.todayMinutes,
      todaySessions: stats.todaySessions,
      streak: stats.streak,
      goalMinutes: settings.dailyGoalMinutes,
      progress: goalProgress,
    );
    final quote = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.eco_rounded, size: 13, color: context.surfaces.faint),
        const SizedBox(width: 5),
        Text(
          '慢一点，也是在往前走。',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.4,
            color: context.surfaces.faint,
          ),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                if (!wide) {
                  return Column(
                    children: [
                      _BrandBar(now: now),
                      const SizedBox(height: 18),
                      phaseSwitch,
                      const SizedBox(height: 12),
                      dial,
                      const SizedBox(height: 12),
                      controls,
                      const SizedBox(height: 18),
                      taskCard,
                      const SizedBox(height: 14),
                      goalCard,
                      const SizedBox(height: 14),
                      quote,
                    ],
                  );
                }
                return Column(
                  children: [
                    _BrandBar(now: now),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              phaseSwitch,
                              const SizedBox(height: 12),
                              wideDial,
                              const SizedBox(height: 12),
                              controls,
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              taskCard,
                              const SizedBox(height: 14),
                              goalCard,
                              const SizedBox(height: 14),
                              _TodayFocusCard(stats: stats, now: now),
                              const SizedBox(height: 14),
                              _FocusTipCard(phase: timer.phase),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    quote,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  const _TodayFocusCard({required this.stats, required this.now});

  final StatsController stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final sessions = stats.sessionsOn(now).take(3).toList(growable: false);
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '今日足迹',
            subtitle: '${stats.todayMinutes} 分钟 · ${stats.todaySessions} 颗番茄',
            trailing: Icon(
              Icons.insights_rounded,
              size: 17,
              color: surfaces.faint,
            ),
          ),
          const SizedBox(height: 10),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.local_florist_outlined,
                    size: 18,
                    color: surfaces.faint,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '今天还没有专注记录。选一颗任务，种下第一颗番茄。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: surfaces.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < sessions.length; i += 1) ...[
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(
                        alpha: context.isDark ? 0.18 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      sessions[i].taskTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clockLabel(sessions[i].endedAt),
                    style: TextStyle(fontSize: 10, color: surfaces.faint),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${sessions[i].minutes}′',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
              if (i != sessions.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Divider(
                    height: 1,
                    color: surfaces.border.withValues(alpha: 0.5),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _FocusTipCard extends StatelessWidget {
  const _FocusTipCard({required this.phase});

  final PomodoroPhase phase;

  @override
  Widget build(BuildContext context) {
    final (title, text, icon) = switch (phase) {
      PomodoroPhase.focus => (
        '专注提示',
        '把手机翻个面。此刻只做一件事，剩下的等番茄落袋再说。',
        Icons.visibility_outlined,
      ),
      PomodoroPhase.shortBreak => (
        '小憩提示',
        '站起来伸个懒腰，看看六米以外的风景。',
        Icons.eco_outlined,
      ),
      PomodoroPhase.longBreak => (
        '长休息提示',
        '泡杯茶，让眼睛和大脑都真正离开屏幕一会儿。',
        Icons.nights_stay_outlined,
      ),
    };
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      color: surfaces.cardMuted.withValues(alpha: 0.55),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: surfaces.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: surfaces.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.6,
                    color: surfaces.faint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      children: [
        const TomatoMark(size: 38, withGlow: true),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '落·番茄',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(letterSpacing: 1.5, fontSize: 21),
              ),
              const SizedBox(height: 2),
              Text(
                '${greetingForHour(now.hour)}，把时间种成番茄',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                  color: surfaces.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InfoPill(
          icon: Icons.wb_sunny_outlined,
          label: '${now.month}月${now.day}日 · 周${weekdayShort(now)}',
        ),
      ],
    );
  }
}

class _PhaseSwitch extends StatelessWidget {
  const _PhaseSwitch({required this.timer});

  final PomodoroController timer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaces.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          for (final phase in PomodoroPhase.values)
            Expanded(
              child: _PhaseTab(
                phase: phase,
                selected: timer.phase == phase,
                onTap: () {
                  if (timer.phase == phase) return;
                  if (timer.isRunning) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('先暂停，再切换阶段吧')),
                      );
                    return;
                  }
                  HapticFeedback.selectionClick();
                  timer.switchPhase(phase);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PhaseTab extends StatelessWidget {
  const _PhaseTab({
    required this.phase,
    required this.selected,
    required this.onTap,
  });

  final PomodoroPhase phase;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = visualsFor(phase);
    final surfaces = context.surfaces;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? visuals.accent.withValues(alpha: context.isDark ? 0.9 : 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              visuals.icon,
              size: 14,
              color: selected ? Colors.white : surfaces.muted,
            ),
            const SizedBox(width: 5),
            Text(
              phase.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : surfaces.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerControls extends StatelessWidget {
  const _TimerControls({required this.timer});

  final PomodoroController timer;

  @override
  Widget build(BuildContext context) {
    final visuals = visualsFor(timer.phase);
    final surfaces = context.surfaces;
    final isRunning = timer.isRunning;
    final label = switch (timer.status) {
      PomodoroStatus.running =>
        timer.phase == PomodoroPhase.focus ? '正在专注，点按暂停' : '正在休息，点按暂停',
      PomodoroStatus.paused => '已暂停，继续加油',
      PomodoroStatus.idle =>
        timer.phase == PomodoroPhase.focus ? '点按开始，种下一颗番茄' : '点按开始休息',
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleIconButton(
              icon: Icons.replay_rounded,
              tooltip: '重新开始这一阶段',
              size: 46,
              onPressed: () {
                HapticFeedback.selectionClick();
                timer.reset();
              },
            ),
            const SizedBox(width: 22),
            Semantics(
              button: true,
              label: isRunning ? '暂停计时' : '开始计时',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (timer.isRunning) {
                    timer.pause();
                  } else {
                    launchFocusSession(context);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: visuals.gradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: visuals.accent.withValues(alpha: 0.32),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(isRunning),
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 22),
            CircleIconButton(
              icon: Icons.skip_next_rounded,
              tooltip: timer.phase == PomodoroPhase.focus ? '跳过这段专注' : '结束休息',
              size: 46,
              onPressed: () {
                HapticFeedback.selectionClick();
                timer.skip();
              },
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: surfaces.faint,
            letterSpacing: 0.2,
          ),
        ),
        if (timer.isRunning)
          TextButton.icon(
            onPressed: () => launchFocusSession(context),
            icon: const Icon(Icons.open_in_full_rounded, size: 14),
            label: const Text('进入沉浸专注'),
          ),
      ],
    );
  }
}

class _FocusTaskCard extends StatelessWidget {
  const _FocusTaskCard({required this.timer, required this.task});

  final PomodoroController timer;
  final Task? task;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final currentTask = task;
    final tag = currentTask?.tag;
    final accent = tag == null ? context.primary : AppPalette.tag(tag);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      onTap: () => showFocusTaskPicker(context),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: context.isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              task == null
                  ? Icons.add_task_rounded
                  : Icons.local_florist_rounded,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task?.title ?? '选择要专注的任务',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTask == null
                      ? '选一颗待办，让每颗番茄都有落处'
                      : (currentTask.hasTarget
                            ? '${currentTask.isHabit ? currentTask.scheduleLabel() : currentTask.kind.shortLabel} · ${currentTask.focusMinutes} 分钟/次 · ${currentTask.progressLabel(DateTime.now())}'
                            : '${currentTask.kind.shortLabel} · ${currentTask.focusMinutes} 分钟/次 · 已收获 ${currentTask.completedPomodoros} 颗番茄'),
                  style: TextStyle(fontSize: 11.5, color: surfaces.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (timer.isRunning)
            Tooltip(
              message: '专注中，暂停后可更换任务',
              child: Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: surfaces.faint,
              ),
            )
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: surfaces.faint),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.todayMinutes,
    required this.todaySessions,
    required this.streak,
    required this.goalMinutes,
    required this.progress,
  });

  final int todayMinutes;
  final int todaySessions;
  final int streak;
  final int goalMinutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final done = todayMinutes >= goalMinutes;
    final remaining = math.max(0, goalMinutes - todayMinutes);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '今日专注',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: surfaces.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (done)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '已达成',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$todayMinutes',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: context.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ $goalMinutes 分钟',
                          style: TextStyle(fontSize: 12, color: surfaces.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _MiniStat(
                    icon: Icons.local_florist_rounded,
                    value: '$todaySessions',
                    label: '颗番茄',
                  ),
                  const SizedBox(width: 16),
                  _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    value: '$streak',
                    label: '天连续',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          SoftProgressBar(
            value: progress,
            height: 7,
            gradient: LinearGradient(
              colors: [scheme.primary, AppPalette.apricot],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            done ? '今日目标达成，剩下的时间留一点给自己。' : '再专注 $remaining 分钟，就达成今日目标。',
            style: TextStyle(fontSize: 10.5, color: surfaces.faint),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: surfaces.muted),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w700,
                color: context.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9.5, color: surfaces.faint)),
      ],
    );
  }
}
