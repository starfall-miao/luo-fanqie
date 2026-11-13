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
import '../../stats/models/interruption_event.dart';
import '../../stats/providers/stats_controller.dart';
import 'widgets/focus_heatmap.dart';
import 'widgets/weekly_chart.dart';

enum _StatsRange { day, week, month, year }

extension on _StatsRange {
  String get label => switch (this) {
    _StatsRange.day => '日',
    _StatsRange.week => '周',
    _StatsRange.month => '月',
    _StatsRange.year => '年',
  };
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _StatsRange _range = _StatsRange.week;

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
    final rangeTabs = _RangeTabs(
      selected: _range,
      onChanged: (range) => setState(() => _range = range),
    );
    final periodTable = _PeriodTable(stats: stats, range: _range, now: now);
    final interruptionCard = _InterruptionCard(
      stats: stats,
      range: _range,
      now: now,
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
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
                      const SizedBox(height: 16),
                      rangeTabs,
                      const SizedBox(height: 14),
                      periodTable,
                      const SizedBox(height: 14),
                      hero,
                      const SizedBox(height: 12),
                      strip,
                      const SizedBox(height: 14),
                      chartCard,
                      const SizedBox(height: 14),
                      heatmapCard,
                      const SizedBox(height: 14),
                      recent,
                      const SizedBox(height: 14),
                      interruptionCard,
                      const SizedBox(height: 18),
                      quote,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 16),
                    rangeTabs,
                    const SizedBox(height: 14),
                    periodTable,
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 14),
                    interruptionCard,
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

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final _StatsRange selected;
  final ValueChanged<_StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaces.cardMuted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          for (final range in _StatsRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == range
                        ? scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected == range
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected == range
                          ? scheme.onPrimary
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

class _RangeRow {
  const _RangeRow({
    required this.label,
    required this.detail,
    required this.sessions,
    required this.minutes,
  });

  final String label;
  final String detail;
  final int sessions;
  final int minutes;
}

class _PeriodTable extends StatelessWidget {
  const _PeriodTable({
    required this.stats,
    required this.range,
    required this.now,
  });

  final StatsController stats;
  final _StatsRange range;
  final DateTime now;

  List<_RangeRow> _rows() {
    switch (range) {
      case _StatsRange.day:
        final sessions = stats.sessionsOn(now);
        if (sessions.isEmpty) {
          return const [
            _RangeRow(label: '今天', detail: '还没有专注记录', sessions: 0, minutes: 0),
          ];
        }
        return [
          for (final session in sessions)
            _RangeRow(
              label: clockLabel(session.endedAt),
              detail: session.taskTitle,
              sessions: 1,
              minutes: session.minutes,
            ),
        ];
      case _StatsRange.week:
        const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final week = stats.currentWeek();
        return [
          for (var i = 0; i < week.length; i += 1)
            _RangeRow(
              label: weekdays[i],
              detail: '${week[i].date.month}/${week[i].date.day}',
              sessions: week[i].sessions,
              minutes: week[i].minutes,
            ),
        ];
      case _StatsRange.month:
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final rows = <_RangeRow>[];
        for (var startDay = 1; startDay <= daysInMonth; startDay += 7) {
          final endDay = math.min(startDay + 6, daysInMonth);
          final start = DateTime(now.year, now.month, startDay);
          final end = DateTime(now.year, now.month, endDay + 1);
          final sessions = stats.sessionsBetween(start, end);
          rows.add(
            _RangeRow(
              label: startDay == endDay ? '$startDay日' : '$startDay–$endDay日',
              detail: '${now.month}月第${rows.length + 1}周',
              sessions: sessions.length,
              minutes: sessions.fold<int>(0, (sum, s) => sum + s.minutes),
            ),
          );
        }
        return rows;
      case _StatsRange.year:
        return [
          for (var month = 1; month <= 12; month += 1)
            _RangeRow(
              label: '$month月',
              detail: '${now.year}',
              sessions: stats
                  .sessionsBetween(
                    DateTime(now.year, month, 1),
                    DateTime(now.year, month + 1, 1),
                  )
                  .length,
              minutes: stats
                  .sessionsBetween(
                    DateTime(now.year, month, 1),
                    DateTime(now.year, month + 1, 1),
                  )
                  .fold<int>(0, (sum, s) => sum + s.minutes),
            ),
        ];
    }
  }

  String get _title => '${range.label}统计表';

  String get _subtitle => switch (range) {
    _StatsRange.day => '${now.month}月${now.day}日 · 今日专注',
    _StatsRange.week => '本周一至周日',
    _StatsRange.month => '${now.year}年${now.month}月 · 按周汇总',
    _StatsRange.year => '${now.year}年 · 按月汇总',
  };

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final rows = _rows();
    final totalSessions = rows.fold<int>(0, (sum, row) => sum + row.sessions);
    final totalMinutes = rows.fold<int>(0, (sum, row) => sum + row.minutes);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: _title,
            subtitle: _subtitle,
            trailing: Text(
              '$totalSessions 颗 · $totalMinutes 分钟',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TableHeader('时段')),
              SizedBox(width: 74, child: _TableHeader('番茄', alignEnd: true)),
              SizedBox(width: 74, child: _TableHeader('分钟', alignEnd: true)),
            ],
          ),
          const SizedBox(height: 5),
          for (var i = 0; i < rows.length; i += 1) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: surfaces.border.withValues(alpha: 0.38),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: context.onSurface,
                          ),
                        ),
                        if (rows[i].detail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            rows[i].detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: surfaces.faint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${rows[i].sessions}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${rows[i].minutes}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, {this.alignEnd = false});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.4,
        color: context.surfaces.faint,
      ),
    );
  }
}

class _InterruptionCard extends StatelessWidget {
  const _InterruptionCard({
    required this.stats,
    required this.range,
    required this.now,
  });

  final StatsController stats;
  final _StatsRange range;
  final DateTime now;

  (DateTime, DateTime) get _bounds {
    final startOfToday = startOfDay(now);
    return switch (range) {
      _StatsRange.day => (startOfToday, addDays(startOfToday, 1)),
      _StatsRange.week => (startOfWeek(now), addDays(startOfWeek(now), 7)),
      _StatsRange.month => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
      ),
      _StatsRange.year => (
        DateTime(now.year, 1, 1),
        DateTime(now.year + 1, 1, 1),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final (start, end) = _bounds;
    final events = stats.interruptionsBetween(start, end);
    final grouped = <String, List<InterruptionEvent>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.reason, () => []).add(event);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '打断原因',
            subtitle: '${range.label}统计 · 共 ${events.length} 次',
            trailing: Icon(
              Icons.pause_circle_outline_rounded,
              size: 18,
              color: surfaces.muted,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              '这段时间没有被主动打断，落落为你骄傲。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: surfaces.faint,
              ),
            )
          else
            for (final entry in entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(fontSize: 12, color: context.onSurface),
                    ),
                  ),
                  Text(
                    '${entry.value.length} 次',
                    style: TextStyle(fontSize: 11, color: surfaces.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SoftProgressBar(
                value: entry.value.length / events.length,
                height: 5,
                color: AppPalette.apricot,
              ),
              const SizedBox(height: 10),
            ],
        ],
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
