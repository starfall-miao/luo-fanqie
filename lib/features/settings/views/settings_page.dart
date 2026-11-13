import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/immersive/immersive_mode_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_controller.dart';
import '../../stats/providers/stats_controller.dart';
import '../../sync/providers/sync_controller.dart';
import '../../sync/views/sync_settings_sheet.dart';
import 'security_page.dart';
import '../../tasks/providers/task_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _ensureStrictGuard(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    const service = ImmersiveModeService();
    final enabled = await service.isStrictGuardEnabled();
    if (enabled || !context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开启学霸守护？'),
        content: const Text(
          '学霸模式可以用「无障碍置顶守护」在你切到其他 App 时，铺满屏幕提醒你回到专注，并在计时结束后自动回到落·番茄。\n\n'
          '它只读取当前前台应用的包名，不读取屏幕文字、密码或聊天内容。你可以随时关闭学霸模式，或在系统无障碍设置里停用服务。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去开启'),
          ),
        ],
      ),
    );
    if (go == true) await service.openAccessibilitySettings();
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = context.watch<SettingsController>();
    final settings = settingsController.settings;
    final stats = context.watch<StatsController>();
    final tasks = context.watch<TaskController>();
    final sync = context.watch<SyncController>();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      eyebrow: '我的',
                      title: '和落落一起，慢慢专注',
                      subtitle: '调成适合自己的节奏，落落会一直在旁边。',
                    ),
                    const SizedBox(height: 20),
                    _ProfileCard(
                      streak: stats.streak,
                      totalSessions: stats.totalSessions,
                      todayMinutes: stats.todayMinutes,
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '专注节奏'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.timer_rounded,
                            title: '专注时长',
                            subtitle: '一颗番茄有多久',
                            value: '${settings.focusMinutes} 分钟',
                            onTap: () async {
                              final result = await _showNumberSheet(
                                context,
                                title: '专注时长',
                                description: '让一颗番茄刚好装下一段注意力。',
                                value: settings.focusMinutes,
                                min: 5,
                                max: 90,
                                step: 5,
                                unit: '分钟',
                                presets: const [15, 25, 45, 60],
                              );
                              if (result != null) {
                                settingsController.setFocusMinutes(result);
                              }
                            },
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.coffee_rounded,
                            title: '短休息',
                            subtitle: '每颗番茄之间的小憩',
                            value: '${settings.shortBreakMinutes} 分钟',
                            onTap: () async {
                              final result = await _showNumberSheet(
                                context,
                                title: '短休息',
                                description: '起身伸个懒腰，让眼睛看看远处。',
                                value: settings.shortBreakMinutes,
                                min: 1,
                                max: 30,
                                step: 1,
                                unit: '分钟',
                                presets: const [3, 5, 10],
                              );
                              if (result != null) {
                                settingsController.setShortBreakMinutes(result);
                              }
                            },
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.nights_stay_rounded,
                            title: '长休息',
                            subtitle: '完成一组番茄后的奖励',
                            value: '${settings.longBreakMinutes} 分钟',
                            onTap: () async {
                              final result = await _showNumberSheet(
                                context,
                                title: '长休息',
                                description: '一组结束后，值得更从容的休息。',
                                value: settings.longBreakMinutes,
                                min: 5,
                                max: 60,
                                step: 5,
                                unit: '分钟',
                                presets: const [10, 15, 20, 30],
                              );
                              if (result != null) {
                                settingsController.setLongBreakMinutes(result);
                              }
                            },
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.all_inclusive_rounded,
                            title: '长休息间隔',
                            subtitle: '每完成几颗番茄进入长休息',
                            value: '每 ${settings.roundsPerLongBreak} 颗',
                            onTap: () async {
                              final result = await _showNumberSheet(
                                context,
                                title: '长休息间隔',
                                description: '一组番茄的数量，建议 3 到 5 颗。',
                                value: settings.roundsPerLongBreak,
                                min: 2,
                                max: 8,
                                step: 1,
                                unit: '颗',
                                presets: const [2, 3, 4, 5, 6],
                              );
                              if (result != null) {
                                settingsController.setRoundsPerLongBreak(
                                  result,
                                );
                              }
                            },
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.flag_rounded,
                            title: '每日目标',
                            subtitle: '今天想专注多久',
                            value: '${settings.dailyGoalMinutes} 分钟',
                            onTap: () async {
                              final result = await _showNumberSheet(
                                context,
                                title: '每日目标',
                                description: '一个够得着的目标，更容易被完成。',
                                value: settings.dailyGoalMinutes,
                                min: 30,
                                max: 480,
                                step: 30,
                                unit: '分钟',
                                presets: const [60, 90, 120, 180, 240],
                              );
                              if (result != null) {
                                settingsController.setDailyGoalMinutes(result);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '自动化与提醒'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SwitchRow(
                            icon: Icons.play_circle_outline_rounded,
                            title: '自动开始休息',
                            subtitle: '专注结束后，小憩自动开始',
                            value: settings.autoStartBreak,
                            onChanged: settingsController.setAutoStartBreak,
                          ),
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.autorenew_rounded,
                            title: '自动开始下一颗',
                            subtitle: '休息结束后，继续下一轮专注',
                            value: settings.autoStartFocus,
                            onChanged: settingsController.setAutoStartFocus,
                          ),
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.notifications_active_outlined,
                            title: '系统通知',
                            subtitle: '结束计时后在通知栏提醒（Android）',
                            value: settings.notificationsEnabled,
                            onChanged:
                                settingsController.setNotificationsEnabled,
                          ),
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.shield_moon_outlined,
                            title: '学霸模式',
                            subtitle: '切换 App 时全屏提醒，计时结束自动回来（Android 无障碍守护）',
                            value: settings.strictMode,
                            onChanged: (value) async {
                              settingsController.setStrictMode(value);
                              if (value) await _ensureStrictGuard(context);
                            },
                          ),
                          if (!kIsWeb &&
                              defaultTargetPlatform ==
                                  TargetPlatform.android) ...[
                            _RowDivider(),
                            _SettingRow(
                              icon: Icons.accessibility_new_rounded,
                              title: '学霸守护设置',
                              subtitle: '打开系统无障碍设置，开启或关闭置顶守护',
                              value: '',
                              onTap: () => const ImmersiveModeService()
                                  .openAccessibilitySettings(),
                            ),
                          ],
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.volume_up_outlined,
                            title: '声音提醒',
                            subtitle: '番茄完成时播放提示音',
                            value: settings.soundEnabled,
                            onChanged: settingsController.setSoundEnabled,
                          ),
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.vibration_rounded,
                            title: '震动反馈',
                            subtitle: '完成番茄时轻轻震动一下',
                            value: settings.hapticsEnabled,
                            onChanged: settingsController.setHapticsEnabled,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '外观'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.all(8),
                      radius: 24,
                      child: Row(
                        children: [
                          for (final mode in AppThemeMode.values)
                            Expanded(
                              child: _ThemeOption(
                                mode: mode,
                                selected: settings.themeMode == mode,
                                onTap: () =>
                                    settingsController.setThemeMode(mode),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SwitchRow(
                            icon: Icons.blur_on_rounded,
                            title: '毛玻璃效果',
                            subtitle: '更通透，但低端设备可能掉帧；关闭更流畅',
                            value: settings.glassEffects,
                            onChanged: settingsController.setGlassEffects,
                          ),
                          _RowDivider(),
                          _SwitchRow(
                            icon: Icons.pets_rounded,
                            title: '落落看板娘',
                            subtitle: '让猫娘落落陪你一起专注',
                            value: settings.companionEnabled,
                            onChanged: settingsController.setCompanionEnabled,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '数据'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.cleaning_services_outlined,
                            title: '清除已完成任务',
                            subtitle: tasks.completed.isEmpty
                                ? '暂时没有已完成任务'
                                : '共 ${tasks.completed.length} 个，专注记录会保留',
                            value: '',
                            onTap: () async {
                              if (tasks.completed.isEmpty) return;
                              final confirmed = await showConfirmDialog(
                                context,
                                title: '清除已完成任务？',
                                message:
                                    '将移除 ${tasks.completed.length} 个已完成任务，专注记录和统计数据不会受到影响。',
                                confirmText: '清除',
                                destructive: true,
                              );
                              if (!confirmed || !context.mounted) return;
                              final count = tasks.clearCompleted();
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text('已清理 $count 个任务')),
                                );
                            },
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.delete_sweep_outlined,
                            title: '清空专注记录',
                            subtitle: stats.totalSessions == 0
                                ? '还没有专注记录'
                                : '共 $stats.totalSessions 条，无法恢复',
                            value: '',
                            onTap: () async {
                              if (stats.totalSessions == 0) return;
                              final confirmed = await showConfirmDialog(
                                context,
                                title: '清空所有专注记录？',
                                message: '统计图表和连续天数将被重置，已收获的任务番茄数不会改变。此操作无法撤销。',
                                confirmText: '清空',
                                destructive: true,
                              );
                              if (!confirmed || !context.mounted) return;
                              stats.clearAll();
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(content: Text('专注记录已清空')),
                                );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '跨设备同步'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.cloud_sync_rounded,
                            title: '文件服务器同步',
                            subtitle: sync.isConfigured
                                ? (sync.lastError ??
                                      (sync.autoSync ? '自动同步已开启' : '手动同步'))
                                : 'WebDAV / Alist / FTP，自建才安全',
                            value: sync.statusLabel,
                            onTap: () => showSyncSettings(context),
                          ),
                          if (sync.isConfigured) ...[
                            _RowDivider(),
                            _SettingRow(
                              icon: Icons.sync_rounded,
                              title: '立即同步',
                              subtitle: sync.lastSyncAt == null
                                  ? '还没有同步过'
                                  : '上次同步 ${relativeDayLabel(sync.lastSyncAt!)} ${clockLabel(sync.lastSyncAt!)}',
                              value: sync.isSyncing ? '同步中…' : '',
                              onTap: sync.isSyncing
                                  ? null
                                  : () async {
                                      final ok = await sync.syncNow();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ok
                                                  ? '同步完成，任务和专注记录已合并'
                                                  : (sync.lastError ?? '同步失败'),
                                            ),
                                          ),
                                        );
                                    },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(title: '关于落·番茄'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 24,
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.shield_outlined,
                            title: '只属于你的数据',
                            subtitle: '所有任务与记录只保存在本机',
                            value: '',
                            onTap: null,
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.verified_user_outlined,
                            title: '安全与权限',
                            subtitle: '数据去向、按需权限与文件服务器说明',
                            value: '',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SecurityPage(),
                              ),
                            ),
                          ),
                          _RowDivider(),
                          _SettingRow(
                            icon: Icons.info_outline_rounded,
                            title: '版本',
                            subtitle: '落·番茄',
                            value: '1.5.0',
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: '落·番茄',
                              applicationVersion: '1.5.0',
                              applicationLegalese: '把时间种成番茄。',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Center(child: TomatoMark(size: 34)),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '落·番茄 · 把时间种成番茄',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: context.surfaces.faint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '用 Flutter 认真制作',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: context.surfaces.faint.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 940) return content;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 300,
                      child: _SettingsSidebar(
                        sync: sync,
                        stats: stats,
                        settings: settings,
                      ),
                    ),
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

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.sync,
    required this.stats,
    required this.settings,
  });

  final SyncController sync;
  final StatsController stats;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final progress = settings.dailyGoalMinutes == 0
        ? 0.0
        : stats.todayMinutes / settings.dailyGoalMinutes;
    return Column(
      children: [
        SoftCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 7),
                  Text(
                    '今日专注',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${stats.todayMinutes}',
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: context.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '分钟 · ${stats.todaySessions} 颗番茄 · 连续 ${stats.streak} 天',
                style: TextStyle(fontSize: 10.5, color: surfaces.faint),
              ),
              const SizedBox(height: 12),
              SoftProgressBar(value: progress, height: 6),
              const SizedBox(height: 8),
              Text(
                '目标 ${settings.dailyGoalMinutes} 分钟',
                style: TextStyle(fontSize: 10, color: surfaces.faint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    size: 16,
                    color: sync.isConfigured ? scheme.primary : surfaces.faint,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '同步状态',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                sync.isConfigured
                    ? (sync.autoSync ? '自动同步已开启' : '手动同步')
                    : '未开启，数据只在本机',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sync.lastError ??
                    (sync.lastSyncAt == null
                        ? '只连接你自己填写的文件服务器。'
                        : '上次同步 ${relativeDayLabel(sync.lastSyncAt!)} ${clockLabel(sync.lastSyncAt!)}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.55,
                  color: surfaces.faint,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showSyncSettings(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(sync.isConfigured ? '管理同步' : '开启同步'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco_rounded, size: 16, color: surfaces.faint),
                  const SizedBox(width: 7),
                  Text(
                    '桌面小贴士',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '把窗口放在屏幕一侧，拨一颗番茄，让桌面也成为一个安静的自习室。',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.7,
                  color: surfaces.faint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.streak,
    required this.totalSessions,
    required this.todayMinutes,
  });

  final int streak;
  final int totalSessions;
  final int todayMinutes;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primary.withValues(
                alpha: context.isDark ? 0.18 : 0.09,
              ),
              border: Border.all(color: surfaces.border.withValues(alpha: 0.9)),
            ),
            alignment: Alignment.center,
            child: const TomatoMark(size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '番茄种植者',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 5),
                Text(
                  totalSessions == 0
                      ? '今天也来种下第一颗番茄吧'
                      : '已种下 $totalSessions 颗番茄 · 今日 $todayMinutes 分钟',
                  style: TextStyle(fontSize: 11, color: surfaces.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InfoPill(
            icon: Icons.local_fire_department_rounded,
            label: '$streak 天',
            color: streak > 0 ? AppPalette.tomato : surfaces.muted,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: context.surfaces.muted,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 58, right: 16),
      child: Divider(
        height: 1,
        color: context.surfaces.border.withValues(alpha: 0.55),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(
                  alpha: context.isDark ? 0.15 : 0.075,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: scheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: surfaces.faint,
                    ),
                  ),
                ],
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: surfaces.muted,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: surfaces.faint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(
                alpha: context.isDark ? 0.15 : 0.075,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: scheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: surfaces.faint),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (next) {
              HapticFeedback.selectionClick();
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final (label, icon) = switch (mode) {
      AppThemeMode.system => ('跟随系统', Icons.brightness_auto_rounded),
      AppThemeMode.light => ('浅色', Icons.light_mode_rounded),
      AppThemeMode.dark => ('深色', Icons.dark_mode_rounded),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: context.isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? scheme.primary : surfaces.muted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.primary : surfaces.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> _showNumberSheet(
  BuildContext context, {
  required String title,
  required String description,
  required int value,
  required int min,
  required int max,
  required int step,
  required String unit,
  required List<int> presets,
}) {
  var current = value;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (sheetContext) {
      final surfaces = sheetContext.surfaces;
      final scheme = Theme.of(sheetContext).colorScheme;
      return StatefulBuilder(
        builder: (context, setModalState) {
          final safePresets = presets
              .where((preset) => preset >= min && preset <= max)
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: surfaces.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(fontSize: 11.5, color: surfaces.muted),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$current',
                        style: TextStyle(
                          fontSize: 54,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        unit,
                        style: TextStyle(fontSize: 13, color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: current.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: ((max - min) / step).round().clamp(1, 1000),
                  onChanged: (value) => setModalState(
                    () => current = (value / step).round() * step,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$min',
                        style: TextStyle(fontSize: 10, color: surfaces.faint),
                      ),
                      Text(
                        '$max',
                        style: TextStyle(fontSize: 10, color: surfaces.faint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in safePresets)
                      GestureDetector(
                        onTap: () => setModalState(() => current = preset),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: current == preset
                                ? scheme.primary.withValues(alpha: 0.12)
                                : surfaces.cardMuted.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$preset $unit',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: current == preset
                                  ? scheme.primary
                                  : surfaces.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(current),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
