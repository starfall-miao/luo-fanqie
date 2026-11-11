import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../models/focus_session.dart';

class FocusHeatmap extends StatelessWidget {
  const FocusHeatmap({super.key, required this.days});

  /// 按日期升序排列，长度应为 7 的倍数。
  final List<DayStat> days;

  Color _cellColor(BuildContext context, int minutes) {
    final scheme = Theme.of(context).colorScheme;
    if (minutes <= 0) return context.surfaces.track.withValues(alpha: 0.55);
    if (minutes < 15) return scheme.primary.withValues(alpha: 0.22);
    if (minutes < 30) return scheme.primary.withValues(alpha: 0.40);
    if (minutes < 60) return scheme.primary.withValues(alpha: 0.62);
    return scheme.primary.withValues(alpha: 0.90);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    if (days.isEmpty) return const SizedBox.shrink();
    final weekCount = (days.length / 7).ceil();
    final today = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        const labelWidth = 16.0;
        final rawCell =
            (constraints.maxWidth - labelWidth - 8 - (weekCount - 1) * gap) /
            weekCount;
        final cell = rawCell.clamp(9.0, 16.0);
        final monthLabels = <int, String>{};
        for (var week = 0; week < weekCount; week += 1) {
          final first = days[week * 7].date;
          final previous = week == 0 ? null : days[(week - 1) * 7].date;
          if (previous == null || first.month != previous.month) {
            monthLabels[week] = '${first.month}月';
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: labelWidth + 8),
                for (var week = 0; week < weekCount; week += 1)
                  SizedBox(
                    width: cell,
                    height: 14,
                    child: monthLabels.containsKey(week)
                        ? Text(
                            monthLabels[week]!,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: surfaces.faint,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: [
                      for (var row = 0; row < 7; row += 1)
                        SizedBox(
                          height: cell + gap,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              switch (row) {
                                0 => '一',
                                2 => '三',
                                4 => '五',
                                6 => '日',
                                _ => '',
                              },
                              style: TextStyle(
                                fontSize: 8.5,
                                color: surfaces.faint,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < weekCount; week += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          right: week == weekCount - 1 ? 0 : gap,
                        ),
                        child: Column(
                          children: [
                            for (var row = 0; row < 7; row += 1)
                              _HeatCell(
                                day: days[week * 7 + row],
                                size: cell,
                                isToday: isSameDay(
                                  days[week * 7 + row].date,
                                  today,
                                ),
                                color: _cellColor(
                                  context,
                                  days[week * 7 + row].minutes,
                                ),
                                gap: gap,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '颜色越深，专注越久',
                  style: TextStyle(fontSize: 9.5, color: surfaces.faint),
                ),
                const Spacer(),
                Text('少', style: TextStyle(fontSize: 9, color: surfaces.faint)),
                const SizedBox(width: 5),
                for (var i = 0; i < 4; i += 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.5),
                        color: i == 0
                            ? surfaces.track.withValues(alpha: 0.55)
                            : Theme.of(context).colorScheme.primary.withValues(
                                alpha: const [0.22, 0.42, 0.65, 0.9][i],
                              ),
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
                Text('多', style: TextStyle(fontSize: 9, color: surfaces.faint)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.size,
    required this.isToday,
    required this.color,
    required this.gap,
  });

  final DayStat day;
  final double size;
  final bool isToday;
  final Color color;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = day.minutes == 0
        ? '${day.date.month}月${day.date.day}日 · 没有专注记录'
        : '${day.date.month}月${day.date.day}日 · ${day.minutes} 分钟 / ${day.sessions} 颗番茄';
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Tooltip(
        message: message,
        waitDuration: const Duration(milliseconds: 250),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.5),
            border: isToday
                ? Border.all(
                    color: scheme.primary.withValues(alpha: 0.8),
                    width: 1.2,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
