import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/models/focus_session.dart';
import '../../stats/providers/stats_controller.dart';
import 'widgets/focus_heatmap.dart';
import 'widgets/weekly_chart.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final settings = context.watch<SettingsController>().settings;
    final now = DateTime.now();
    final week = stats.currentWeek();
    final weekMinutes = week.fold<int>(0, (sum, day) => sum + day.minutes);
    final last7 = stats.lastNDays(7);
    final heatmapDays = stats.heatmap(weeks: 12);
    final goalProgress = settings.dailyGoalMinutes == 0
        ? 0.0
        : stats.todayMinutes / settings.dailyGoalMinutes;

    final header = PageHeader(
      eyebrow: '专注足迹',
      title: '时间留下的形状',
      subtitle: '每一颗番茄，都是一段被认真对待的时间。',
      trailing: InfoPill(
        icon: Icons.calendar_month_rounded,
        label: '${now.month}月',
      ),
    );
    final hero = _TodayHero(
      minutes: stats.todayMinutes,
      sessions: stats.todaySessions,
      streak: stats.streak,
      goal: settings.dailyGoalMinutes,
      progress: goalProgress,
    );
    final strip = _StatStrip(
      streak: stats.streak,
      weekSessions: stats.weekSessions,
      totalMinutes: stats.totalMinutes,
    );
    final chartCard = SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '近 7 天',
            subtitle: '每天专注的分钟数',
            trailing: Text(
              '共 $weekMinutes 分钟',
              style: TextStyle(fontSize: 11, color: context.surfaces.muted),
            ),
          ),
          const SizedBox(height: 6),
          WeeklyFocusChart(days: last7),
        ],
      ),
    );
    final heatmapCard = SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '专注热力',
            subtitle: '最近 12 周 · 每格是一天',
            trailing: Text(
              '连续 ${stats.streak} 天',
              style: TextStyle(fontSize: 11, color: context.surfaces.muted),
            ),
          ),
          const SizedBox(height: 16),
          FocusHeatmap(days: heatmapDays),
        ],
      ),
    );
    final recent = _RecentSessions(sessions: stats.recent(limit: 5));
    final quote = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_rounded, size: 13, color: context.surfaces.faint),
          const SizedBox(width: 5),
          Text(
            '种下的时间，终会发芽。',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: context.surfaces.faint,
            ),
          ),
        ],
      ),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 20),
                      hero,
                      const SizedBox(height: 12),
                      strip,
                      const SizedBox(height: 14),
                      chartCard,
                      const SizedBox(height: 14),
                      heatmapCard,
                      const SizedBox(height: 14),
                      recent,
                      const SizedBox(height: 18),
                      quote,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              hero,
                              const SizedBox(height: 12),
                              strip,
                              const SizedBox(height: 14),
                              heatmapCard,
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              chartCard,
                              const SizedBox(height: 14),
                              recent,
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

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.minutes,
    required this.sessions,
    required this.streak,
    required this.goal,
    required this.progress,
  });

  final int minutes;
  final int sessions;
  final int streak;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    const cream = Color(0xFFFFF6EE);
    const softCream = Color(0xFFF6D8C8);
    final done = minutes >= goal;
    final remaining = math.max(0, goal - minutes);
    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [surfaces.heroStart, surfaces.heroEnd],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -58,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppPalette.apricot.withValues(alpha: 0.28),
                    AppPalette.apricot.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '今天',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                            color: softCream.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateTime.now().month}月${DateTime.now().day}日',
                          style: TextStyle(
                            fontSize: 11,
                            color: softCream.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$minutes',
                          style: const TextStyle(
                            fontSize: 52,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: cream,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '分钟',
                          style: TextStyle(
                            fontSize: 13,
                            color: softCream.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _HeroMeta(
                          icon: Icons.local_florist_rounded,
                          text: '$sessions 颗番茄',
                        ),
                        _HeroMeta(
                          icon: Icons.local_fire_department_rounded,
                          text: '连续 $streak 天',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 6,
                        color: Colors.white.withValues(alpha: 0.14),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFD9A8), Color(0xFFFF8A65)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      done ? '今日目标达成，给自己一点奖励吧。' : '距离今日目标还差 $remaining 分钟',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: softCream.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      const TomatoMark(size: 52, withGlow: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const softCream = Color(0xFFF6D8C8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: softCream.withValues(alpha: 0.75)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: softCream.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.streak,
    required this.weekSessions,
    required this.totalMinutes,
  });

  final int streak;
  final int weekSessions;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
      radius: 22,
      child: Row(
        children: [
          _StripItem(
            icon: Icons.local_fire_department_rounded,
            value: '$streak',
            unit: '天',
            label: '连续专注',
            color: AppPalette.tomato,
          ),
          _StripDivider(color: surfaces.border),
          _StripItem(
            icon: Icons.local_florist_rounded,
            value: '$weekSessions',
            unit: '颗',
            label: '本周番茄',
            color: AppPalette.apricot,
          ),
          _StripDivider(color: surfaces.border),
          _StripItem(
            icon: Icons.hourglass_bottom_rounded,
            value: compactMinutes(totalMinutes),
            unit: compactMinutesUnit(totalMinutes),
            label: '累计专注',
            color: AppPalette.plum,
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: context.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(fontSize: 9.5, color: surfaces.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 10, color: surfaces.faint)),
        ],
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: color.withValues(alpha: 0.7));
  }
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '最近记录',
            subtitle: '一颗一颗，都算数',
            trailing: sessions.isEmpty
                ? null
                : Text(
                    '${sessions.length} 条',
                    style: TextStyle(fontSize: 11, color: surfaces.faint),
                  ),
          ),
          const SizedBox(height: 10),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  const TomatoMark(size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '还没有专注记录。\n去专注页，种下今天的第一颗番茄吧。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: surfaces.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < sessions.length; i += 1) ...[
              _SessionRow(session: sessions[i]),
              if (i != sessions.length - 1)
                Divider(
                  height: 1,
                  color: surfaces.border.withValues(alpha: 0.6),
                ),
            ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(
                alpha: context.isDark ? 0.18 : 0.09,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.local_florist_rounded,
              size: 17,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  '${relativeDayLabel(session.endedAt)} ${clockLabel(session.endedAt)}',
                  style: TextStyle(fontSize: 10.5, color: surfaces.faint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${session.minutes}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
          Text('分钟', style: TextStyle(fontSize: 9.5, color: surfaces.faint)),
        ],
      ),
    );
  }
}
