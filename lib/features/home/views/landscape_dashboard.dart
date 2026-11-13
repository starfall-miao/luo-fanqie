import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../companion/luoluo_mascot.dart';
import '../../focus/views/session_page.dart';
import '../../focus/views/widgets/task_picker_sheet.dart';
import '../../focus/views/widgets/timer_dial.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/providers/stats_controller.dart';
import '../../sync/providers/sync_controller.dart';
import '../../sync/views/sync_settings_sheet.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_controller.dart';
import '../../tasks/views/widgets/task_editor_sheet.dart';
import '../../timer/models/pomodoro_phase.dart';
import '../../timer/providers/pomodoro_controller.dart';
import '../../timer/theme/phase_style.dart';

/// 横屏/桌面端仪表盘：不显示标签栏，所有核心内容以卡片铺在一页。
class LandscapeDashboard extends StatelessWidget {
  const LandscapeDashboard({
    super.key,
    required this.onOpenSettings,
    required this.onOpenStats,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final selectedTaskId = context.select<PomodoroController, String?>(
      (timer) => timer.selectedTaskId,
    );
    final timerRunning = context.select<PomodoroController, bool>(
      (timer) => timer.isRunning,
    );
    final tasks = context.watch<TaskController>();
    final stats = context.watch<StatsController>();
    final settings = context.watch<SettingsController>().settings;
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DashboardHeader(
              now: now,
              timerRunning: timerRunning,
              stats: stats,
              onOpenSettings: onOpenSettings,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: _FocusCard(settings: settings, stats: stats),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: _TasksCard(
                      tasks: tasks,
                      selectedTaskId: selectedTaskId,
                      onStart: (task) {
                        if (context.read<PomodoroController>().isRunning) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(content: Text('正在专注中，先暂停再切换待办')),
                            );
                          return;
                        }
                        launchFocusSession(
                          context,
                          task: task,
                          resetPaused: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: _InsightsColumn(
                      tasks: tasks,
                      stats: stats,
                      onOpenSettings: onOpenSettings,
                      onOpenStats: onOpenStats,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.now,
    required this.timerRunning,
    required this.stats,
    required this.onOpenSettings,
  });

  final DateTime now;
  final bool timerRunning;
  final StatsController stats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final sync = context.watch<SyncController>();
    final companionOn = context.select<SettingsController, bool>(
      (controller) => controller.settings.companionEnabled,
    );
    return Row(
      children: [
        if (companionOn)
          LuoLuoMascot(size: 46, studying: timerRunning)
        else
          const TomatoMark(size: 38, withGlow: true),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '落·番茄',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontSize: 21, letterSpacing: 1.4),
                ),
                if (timerRunning) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '专注中',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: context.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${greetingForHour(now.hour)}，落落陪你种番茄',
              style: TextStyle(fontSize: 11, color: surfaces.muted),
            ),
          ],
        ),
        const Spacer(),
        InfoPill(
          icon: Icons.calendar_today_rounded,
          label: '${now.month}月${now.day}日 · 周${weekdayShort(now)}',
        ),
        const SizedBox(width: 8),
        InfoPill(
          icon: Icons.local_fire_department_rounded,
          label: '${stats.streak} 天',
          color: stats.streak > 0 ? AppPalette.tomato : surfaces.muted,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '跨设备同步',
          child: Material(
            color: surfaces.card.withValues(alpha: 0.65),
            shape: CircleBorder(side: BorderSide(color: surfaces.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showSyncSettings(context),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  sync.isSyncing
                      ? Icons.sync_rounded
                      : Icons.cloud_sync_outlined,
                  size: 19,
                  color: sync.isConfigured ? context.primary : surfaces.muted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CircleIconButton(
          icon: Icons.settings_outlined,
          tooltip: '设置',
          size: 42,
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.settings, required this.stats});

  final AppSettings settings;
  final StatsController stats;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final timer = context.watch<PomodoroController>();
    final task = timer.selectedTask;
    final dialSize = math.min(MediaQuery.sizeOf(context).width * 0.22, 272.0);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 26,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('专注', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (settings.strictMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.tomato.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      '学霸',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.tomato,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            _CompactPhaseSwitch(timer: timer),
            const SizedBox(height: 10),
            TimerDial(
              phase: timer.phase,
              status: timer.status,
              progress: timer.progress,
              remainingLabel: timer.remainingLabel,
              roundNumber: timer.roundNumber,
              rounds: settings.roundsPerLongBreak,
              completedInCycle: timer.completedInCycle,
              taskTitle: task?.title,
              maxSize: dialSize,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleIconButton(
                  icon: Icons.replay_rounded,
                  tooltip: '重新开始',
                  size: 40,
                  onPressed: timer.reset,
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    if (timer.isRunning) {
                      timer.pause();
                    } else {
                      launchFocusSession(context);
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: visualsFor(timer.phase).gradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: visualsFor(timer.phase).accent
                              .withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      timer.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 33,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                CircleIconButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: '跳过',
                  size: 40,
                  onPressed: timer.skip,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CompactTaskSelector(timer: timer, task: task),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  if (timer.isRunning) {
                    timer.pause();
                    return;
                  }
                  if (timer.isPaused) timer.reset();
                  timer.selectTask(null);
                  if (timer.phase != PomodoroPhase.focus) {
                    timer.switchPhase(PomodoroPhase.focus);
                  }
                  await launchFocusSession(context, resetPaused: true);
                },
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: const Text('快速开始一颗番茄'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '今日 ${stats.todaySessions} 颗 · ${stats.todayMinutes} 分钟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: surfaces.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPhaseSwitch extends StatelessWidget {
  const _CompactPhaseSwitch({required this.timer});

  final PomodoroController timer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaces.cardMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (final phase in PomodoroPhase.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (timer.isRunning) return;
                  timer.switchPhase(phase);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: timer.phase == phase
                        ? visualsFor(phase).accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    phase.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: timer.phase == phase
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: timer.phase == phase
                          ? Colors.white
                          : surfaces.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactTaskSelector extends StatelessWidget {
  const _CompactTaskSelector({required this.timer, required this.task});

  final PomodoroController timer;
  final Task? task;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showFocusTaskPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: surfaces.cardMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              task == null
                  ? Icons.add_task_rounded
                  : Icons.local_florist_rounded,
              size: 16,
              color: task == null ? surfaces.faint : AppPalette.tag(task!.tag),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                task?.title ?? '选择一个待办',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: context.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 17, color: surfaces.faint),
          ],
        ),
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.selectedTaskId,
    required this.onStart,
  });

  final TaskController tasks;
  final String? selectedTaskId;
  final ValueChanged<Task> onStart;

  @override
  Widget build(BuildContext context) {
    final pending = tasks.pending;
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('待办', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 7),
              Text(
                '${tasks.pendingCount} 项进行中',
                style: TextStyle(fontSize: 10.5, color: surfaces.faint),
              ),
              const Spacer(),
              CircleIconButton(
                icon: Icons.add_rounded,
                tooltip: '新建待办',
                size: 34,
                filled: true,
                onPressed: () => showTaskEditor(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: pending.isEmpty
                ? Center(
                    child: Text(
                      '番茄田空空的，\n落落等你种下第一颗。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: surfaces.muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: pending.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = pending[index];
                      return _DashboardTaskTile(
                        task: task,
                        selected: selectedTaskId == task.id,
                        onTap: () => showTaskEditor(context, task: task),
                        onStart: () => onStart(task),
                        onToggle: task.isHabit
                            ? null
                            : () => context.read<TaskController>().toggleDone(
                                task.id,
                              ),
                      );
                    },
                  ),
          ),
          if (tasks.completed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '今天也完成了 ${tasks.completedTodayCount} 项',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: surfaces.faint),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardTaskTile extends StatelessWidget {
  const _DashboardTaskTile({
    required this.task,
    required this.selected,
    required this.onTap,
    required this.onStart,
    required this.onToggle,
  });

  final Task task;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (task.kind) {
      TaskKind.pomodoro => AppPalette.tomato,
      TaskKind.goal => AppPalette.apricot,
      TaskKind.habit => AppPalette.sage,
    };
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: context.isDark ? 0.14 : 0.07)
          : surfaces.cardMuted.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 7, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onToggle != null)
                GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      task.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 19,
                      color: task.done ? AppPalette.sage : surfaces.faint,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.eco_rounded, size: 17, color: color),
                ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: task.done
                                  ? surfaces.muted
                                  : context.onSurface,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.timer_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        Text(
                          task.kind.shortLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (task.tag.trim().isNotEmpty)
                          Text(
                            task.tag,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: surfaces.muted,
                            ),
                          ),
                        Text(
                          '${task.focusMinutes}′/次',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: surfaces.faint,
                          ),
                        ),
                      ],
                    ),
                    if (task.hasTarget) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: SoftProgressBar(
                              value: task.progressRatio(DateTime.now()),
                              height: 4,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.progressLabel(DateTime.now()),
                            style: TextStyle(
                              fontSize: 9,
                              color: surfaces.faint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onStart,
                tooltip: '开始专注',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: color.withValues(
                    alpha: context.isDark ? 0.2 : 0.1,
                  ),
                  foregroundColor: color,
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightsColumn extends StatelessWidget {
  const _InsightsColumn({
    required this.tasks,
    required this.stats,
    required this.onOpenSettings,
    required this.onOpenStats,
  });

  final TaskController tasks;
  final StatsController stats;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final targets = tasks.tasks
        .where((task) => task.hasTarget && !task.done)
        .take(4)
        .toList();
    return SingleChildScrollView(
      child: Column(
        children: [
          _TodayOverview(
            stats: stats,
            goal: settings.settings.dailyGoalMinutes,
            onOpenStats: onOpenStats,
          ),
          const SizedBox(height: 12),
          _TargetsOverview(targets: targets),
          const SizedBox(height: 12),
          _QuickActions(
            settingsController: settings,
            onOpenSettings: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({
    required this.stats,
    required this.goal,
    required this.onOpenStats,
  });

  final StatsController stats;
  final int goal;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final progress = goal <= 0 ? 0.0 : stats.todayMinutes / goal;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '今日专注',
            subtitle: '${stats.todaySessions} 颗番茄',
            trailing: TextButton(
              onPressed: onOpenStats,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('完整统计'),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${stats.todayMinutes}',
                style: TextStyle(
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: context.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $goal 分钟',
                style: TextStyle(fontSize: 10.5, color: surfaces.faint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SoftProgressBar(
            value: progress,
            height: 6,
            gradient: LinearGradient(
              colors: [scheme.primary, AppPalette.apricot],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 13,
                color: AppPalette.tomato,
              ),
              const SizedBox(width: 4),
              Text(
                '连续 ${stats.streak} 天',
                style: TextStyle(fontSize: 10, color: surfaces.muted),
              ),
              const Spacer(),
              Text(
                progress >= 1 ? '目标达成' : '继续专注',
                style: TextStyle(
                  fontSize: 10,
                  color: progress >= 1 ? AppPalette.sage : surfaces.faint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetsOverview extends StatelessWidget {
  const _TargetsOverview({required this.targets});

  final List<Task> targets;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '目标与习惯',
            subtitle: targets.isEmpty ? '还没有在途目标' : '${targets.length} 个在途',
          ),
          const SizedBox(height: 10),
          if (targets.isEmpty)
            Text(
              '在待办里选择「定目标」或「养习惯」，让每天的专注有方向。',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: surfaces.faint,
              ),
            )
          else
            for (var i = 0; i < targets.length; i += 1) ...[
              _TargetRow(task: targets[i]),
              if (i != targets.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Divider(
                    height: 1,
                    color: surfaces.border.withValues(alpha: 0.45),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = task.isHabit ? AppPalette.sage : AppPalette.apricot;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.isHabit ? Icons.eco_rounded : Icons.flag_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.onSurface,
                  ),
                ),
              ),
              Text(
                task.progressLabel(DateTime.now()),
                style: TextStyle(fontSize: 9.5, color: surfaces.faint),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SoftProgressBar(
            value: task.progressRatio(DateTime.now()),
            height: 4,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.settingsController,
    required this.onOpenSettings,
  });

  final SettingsController settingsController;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final timer = context.watch<PomodoroController>();
    final sync = context.watch<SyncController>();
    final mode = settingsController.settings.themeMode;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '快速设置',
            subtitle: '不用离开当前页',
            trailing: TextButton(
              onPressed: onOpenSettings,
              child: const Text('全部设置'),
            ),
          ),
          const SizedBox(height: 6),
          _QuickRow(
            icon: Icons.cloud_sync_outlined,
            title: '同步',
            value: sync.isConfigured ? (sync.autoSync ? '自动同步' : '手动') : '未开启',
            onTap: () => showSyncSettings(context),
          ),
          Divider(height: 1, color: surfaces.border.withValues(alpha: 0.42)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.brightness_6_outlined,
                  size: 15,
                  color: surfaces.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  '外观',
                  style: TextStyle(fontSize: 11, color: surfaces.muted),
                ),
                const Spacer(),
                _ThemeMiniSwitch(
                  mode: mode,
                  onChanged: settingsController.setThemeMode,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: surfaces.border.withValues(alpha: 0.42)),
          _QuickRow(
            icon: Icons.timer_outlined,
            title: '当前计时',
            value: timer.isRunning ? timer.remainingLabel : '待开始',
            onTap: () {
              if (timer.isRunning) {
                launchFocusSession(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 15, color: surfaces.muted),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 11, color: surfaces.muted)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 10.5, color: surfaces.faint),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 14, color: surfaces.faint),
          ],
        ),
      ),
    );
  }
}

class _ThemeMiniSwitch extends StatelessWidget {
  const _ThemeMiniSwitch({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in AppThemeMode.values)
          GestureDetector(
            onTap: () => onChanged(item),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: mode == item
                    ? scheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                switch (item) {
                  AppThemeMode.system => Icons.brightness_auto_rounded,
                  AppThemeMode.light => Icons.light_mode_rounded,
                  AppThemeMode.dark => Icons.dark_mode_rounded,
                },
                size: 14,
                color: mode == item ? scheme.primary : surfaces.faint,
              ),
            ),
          ),
      ],
    );
  }
}
