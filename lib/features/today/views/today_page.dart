import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../growth/providers/growth_controller.dart';
import '../../integration/services/target_app_service.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/providers/stats_controller.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.onOpenGrowth,
    required this.onOpenGuard,
    required this.onOpenFocus,
    required this.onOpenTasks,
  });

  final VoidCallback onOpenGrowth;
  final VoidCallback onOpenGuard;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final growth = context.watch<GrowthController>();
    final stats = context.watch<StatsController>();
    final now = DateTime.now();
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: '今日',
                  title: '今天，先做最重要的一件事',
                  subtitle: '${now.month}月${now.day}日 · 番茄 ToDo 增强工作台',
                  trailing: InfoPill(
                    icon: Icons.local_fire_department_rounded,
                    label: '${stats.streak} 天',
                  ),
                ),
                const SizedBox(height: 16),
                _IntegrationCard(
                  packageName: settings.targetAppPackage,
                  fallbackLabel: settings.targetAppLabel,
                  onOpenGuard: onOpenGuard,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 700;
                    final growthCard = _GrowthCard(
                      growth: growth,
                      onOpenGrowth: onOpenGrowth,
                    );
                    final side = _SideColumn(
                      settings: settings,
                      stats: stats,
                      onOpenGuard: onOpenGuard,
                      onOpenFocus: onOpenFocus,
                      onOpenTasks: onOpenTasks,
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          growthCard,
                          const SizedBox(height: 14),
                          side,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: growthCard),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: side),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.packageName,
    required this.fallbackLabel,
    required this.onOpenGuard,
  });

  final String packageName;
  final String fallbackLabel;
  final VoidCallback onOpenGuard;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TargetAppStatus>(
      future: const TargetAppService().inspect(
        packageName: packageName,
        fallbackLabel: fallbackLabel,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final installed = status?.installed ?? false;
        return SoftCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.tomato.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: AppPalette.tomato,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${status?.label ?? fallbackLabel} 联动',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      installed
                          ? '已检测到应用 · $packageName'
                          : '未检测到应用或未安装 · $packageName',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(onPressed: onOpenGuard, child: const Text('配置守护')),
            ],
          ),
        );
      },
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.growth, required this.onOpenGrowth});

  final GrowthController growth;
  final VoidCallback onOpenGrowth;

  @override
  Widget build(BuildContext context) {
    final habits = growth.habits.take(4).toList();
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '今日成长',
            subtitle: '${growth.todayChecked}/${growth.todayHabits} 个全天习惯',
            trailing: TextButton(
              onPressed: onOpenGrowth,
              child: const Text('全部'),
            ),
          ),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            Text(
              '番茄 ToDo 之外，也给生活留一点长期积累。',
              style: TextStyle(fontSize: 12, color: context.surfaces.muted),
            )
          else
            for (final habit in habits)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: habit.checkedToday,
                onChanged: (_) => growth.checkInHabit(habit.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(habit.title),
                subtitle: Text(
                  '${habit.area} · 连续 ${habit.streak} 天',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.surfaces.faint,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.settings,
    required this.stats,
    required this.onOpenGuard,
    required this.onOpenFocus,
    required this.onOpenTasks,
  });

  final AppSettings settings;
  final StatsController stats;
  final VoidCallback onOpenGuard;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SectionTitle(
                title: '下一次锁机',
                subtitle: settings.autoLockEnabled
                    ? '${settings.autoLockHour.toString().padLeft(2, '0')}:${settings.autoLockMinute.toString().padLeft(2, '0')} · ${settings.autoLockMinutes} 分钟'
                    : '睡眠 / 重要时段锁机未开启',
                trailing: Icon(
                  Icons.lock_clock_rounded,
                  size: 18,
                  color: context.surfaces.faint,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onOpenGuard,
                child: const Text('调整锁机计划'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('计时与待办', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '番茄 ToDo 之外的备用模块',
                style: TextStyle(fontSize: 11, color: context.surfaces.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenFocus,
                      child: const Text('计时'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenTasks,
                      child: const Text('待办'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '今日 ${stats.todaySessions} 颗 · ${stats.todayMinutes} 分钟',
                style: TextStyle(fontSize: 10.5, color: context.surfaces.faint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
