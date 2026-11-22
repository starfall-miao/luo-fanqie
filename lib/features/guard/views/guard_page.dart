import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/immersive/immersive_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../stats/services/app_usage_service.dart';
import '../../guard/services/auto_lock_service.dart';
import '../../guard/views/app_whitelist_sheet.dart';
import '../../integration/services/target_app_service.dart';
import '../../settings/providers/settings_controller.dart';

class GuardPage extends StatefulWidget {
  const GuardPage({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<GuardPage> createState() => _GuardPageState();
}

class _GuardPageState extends State<GuardPage> {
  static const _immersive = ImmersiveModeService();
  static const _usage = AppUsageService();
  static const _autoLock = AutoLockService();

  bool? _accessibility;
  bool? _notificationListener;
  bool? _dnd;
  bool? _usageAccess;
  bool? _battery;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final accessibility = await _immersive.isStrictGuardEnabled();
    final listener = await _immersive.isNotificationListenerEnabled();
    final dnd = await _immersive.isDndAccessGranted();
    final usage = await _usage.hasAccess();
    final battery = await _autoLock.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _accessibility = accessibility;
      _notificationListener = listener;
      _dnd = dnd;
      _usageAccess = usage;
      _battery = battery;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: '守护',
                  title: '把手机交给落落',
                  subtitle: '检测番茄 ToDo、系统权限、锁机与白名单。',
                  trailing: IconButton(
                    onPressed: _loading ? null : _loadStatuses,
                    tooltip: '刷新权限状态',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<TargetAppStatus>(
                  future: const TargetAppService().inspect(
                    packageName: 'com.plan.kot32.tomatotime',
                    fallbackLabel: '番茄ToDo',
                  ),
                  builder: (context, snapshot) => _GuardCard(
                    title: '番茄 ToDo 联动',
                    subtitle:
                        '${snapshot.data?.label ?? settings.targetAppLabel} · ${settings.targetAppPackage}',
                    children: [
                      _GuardLine(
                        icon: Icons.check_circle_outline_rounded,
                        label: snapshot.data?.installed == true
                            ? '已检测到应用'
                            : '未检测到应用，请确认已安装',
                        tone: snapshot.data?.installed == true
                            ? AppPalette.sage
                            : AppPalette.tomato,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => const TargetAppService().launch(
                                settings.targetAppPackage,
                              ),
                              child: const Text('打开番茄ToDo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: widget.onOpenSettings,
                              child: const Text('权限与锁机设置'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _GuardCard(
                  title: '系统权限',
                  subtitle: _loading ? '正在检查…' : '点击进入对应系统设置',
                  children: [
                    _PermissionRow(
                      icon: Icons.accessibility_new_rounded,
                      label: '无障碍守护',
                      enabled: _accessibility,
                      onTap: _immersive.openAccessibilitySettings,
                    ),
                    _PermissionRow(
                      icon: Icons.notifications_active_outlined,
                      label: '通知使用权',
                      enabled: _notificationListener,
                      onTap: _immersive.openNotificationListenerSettings,
                    ),
                    _PermissionRow(
                      icon: Icons.do_not_disturb_on_outlined,
                      label: '勿扰访问',
                      enabled: _dnd,
                      onTap: _immersive.openDndAccessSettings,
                    ),
                    _PermissionRow(
                      icon: Icons.analytics_outlined,
                      label: '应用使用情况',
                      enabled: _usageAccess,
                      onTap: _usage.openAccessSettings,
                    ),
                    _PermissionRow(
                      icon: Icons.battery_saver_outlined,
                      label: '忽略电池优化',
                      enabled: _battery,
                      onTap: _autoLock.requestIgnoreBatteryOptimizations,
                    ),
                    _PermissionRow(
                      icon: Icons.memory_rounded,
                      label: '自启动权限',
                      enabled: null,
                      value: '去设置',
                      onTap: _autoLock.openAutostartSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _GuardCard(
                  title: '锁机计划',
                  subtitle: settings.autoLockEnabled
                      ? '每天 ${settings.autoLockHour.toString().padLeft(2, '0')}:${settings.autoLockMinute.toString().padLeft(2, '0')} 开始，持续 ${settings.autoLockMinutes} 分钟'
                      : '尚未设置睡眠 / 重要时段锁机',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onOpenSettings,
                            child: const Text('调整计划'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => showAppWhitelistPicker(context),
                            child: Text(
                              settings.whitelistPackages.isEmpty
                                  ? '设置白名单'
                                  : '白名单 ${settings.whitelistPackages.length}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _GuardCard(
                  title: '数据导入',
                  subtitle: '番茄 ToDo 没有公开 API；将通过显式抓取当前页面导入',
                  children: [
                    Text(
                      '下一步接入：无障碍悬浮按钮抓取当前页面文字，再预览确认导入。不会持续读取屏幕内容。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.55,
                        color: context.surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardCard extends StatelessWidget {
  const _GuardCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _GuardLine extends StatelessWidget {
  const _GuardLine({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final bool? enabled;
  final Future<void> Function() onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final color = enabled == null
        ? context.surfaces.faint
        : enabled!
        ? AppPalette.sage
        : AppPalette.tomato;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.surfaces.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12.5)),
            ),
            Text(
              value ??
                  (enabled == null
                      ? '检查中'
                      : enabled!
                      ? '已开启'
                      : '去开启'),
              style: TextStyle(fontSize: 10.5, color: color),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 15, color: color),
          ],
        ),
      ),
    );
  }
}
