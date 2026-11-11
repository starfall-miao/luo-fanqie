import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../models/focus_session.dart';

class WeeklyFocusChart extends StatelessWidget {
  const WeeklyFocusChart({super.key, required this.days});

  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final maxMinutes = days.fold<int>(
      0,
      (max, day) => math.max(max, day.minutes),
    );
    final maxY = maxMinutes <= 60
        ? 60.0
        : (maxMinutes * 1.25 / 30).ceil() * 30.0;
    final interval = maxY / 3;
    final allEmpty = days.every((day) => day.minutes == 0);
    final today = DateTime.now();

    return SizedBox(
      height: 196,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 4),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: surfaces.border.withValues(alpha: 0.55),
                    strokeWidth: 1,
                    dashArray: const [4, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: surfaces.faint,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final day = days[index].date;
                        final isToday = isSameDay(day, today);
                        return SideTitleWidget(
                          meta: meta,
                          space: 10,
                          child: Text(
                            weekdayShort(day),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday ? scheme.primary : surfaces.muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2B1C19),
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = days[group.x];
                      return BarTooltipItem(
                        '${day.minutes} 分钟',
                        const TextStyle(
                          color: Color(0xFFFFF8F1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i += 1)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].minutes.toDouble(),
                          width: 16,
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              scheme.primary.withValues(alpha: 0.62),
                              scheme.primary,
                              AppPalette.apricot,
                            ],
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: surfaces.track.withValues(alpha: 0.32),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            ),
          ),
          if (allEmpty)
            Positioned.fill(
              top: 20,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: surfaces.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: surfaces.border.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      '这一周还没有专注记录，去种一颗番茄吧。',
                      style: TextStyle(fontSize: 11, color: surfaces.muted),
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
