import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/immersive/immersive_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../stats/services/app_usage_service.dart';
import '../../guard/services/auto_lock_service.dart';
import '../../guard/views/app_whitelist_sheet.dart';
import '../../growth/models/growth_item.dart';
import '../../growth/providers/growth_controller.dart';
import '../../integration/services/capture_service.dart';
import '../../integration/services/target_app_service.dart';
import '../../settings/providers/settings_controller.dart';

class GuardPage extends StatefulWidget {
  const GuardPage({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<GuardPage> createState() => _GuardPageState();
}

class _GuardPageState extends State<GuardPage> with WidgetsBindingObserver {
  static const _immersive = ImmersiveModeService();
  static const _usage = AppUsageService();
  static const _autoLock = AutoLockService();
  static const _capture = CaptureService();

  bool? _accessibility;
  bool? _notificationListener;
  bool? _dnd;
  bool? _usageAccess;
  bool? _battery;
  bool _loading = true;
  bool? _captureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _primeCapture();
      await _checkPendingCapture();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
      _checkPendingCapture();
    }
  }

  Future<void> _primeCapture() async {
    if (!mounted) return;
    final settings = context.read<SettingsController>().settings;
    await _capture.setTarget(settings.targetAppPackage);
    final enabled = await _capture.isEnabled();
    if (mounted) setState(() => _captureEnabled = enabled);
  }

  Future<void> _loadStatuses() async {
    final accessibility = await _immersive.isStrictGuardEnabled();
    final listener = await _immersive.isNotificationListenerEnabled();
    final dnd = await _immersive.isDndAccessGranted();
    final usage = await _usage.hasAccess();
    final battery = await _autoLock.isIgnoringBatteryOptimizations();
    final capture = await _capture.isEnabled();
    if (!mounted) return;
    setState(() {
      _accessibility = accessibility;
      _notificationListener = listener;
      _dnd = dnd;
      _usageAccess = usage;
      _battery = battery;
      _captureEnabled = capture;
      _loading = false;
    });
  }

  Future<void> _checkPendingCapture() async {
    if (!mounted) return;
    final texts = await _capture.consumePending();
    if (!mounted || texts.isEmpty) return;
    await _showCapturePreview(texts);
  }

  Future<void> _showCapturePreview(List<String> texts) async {
    final selected = <int>{for (var i = 0; i < texts.length; i += 1) i};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.surfaces.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '预览抓取内容',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '选择要导入为成长项目的文字；原页面内容不会被修改。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.surfaces.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: texts.length,
                    itemBuilder: (context, index) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(index),
                      onChanged: (value) => setSheetState(() {
                        if (value == true) {
                          selected.add(index);
                        } else {
                          selected.remove(index);
                        }
                      }),
                      title: Text(
                        texts[index],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    child: Text('导入 ${selected.length} 项'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final growth = context.read<GrowthController>();
    for (final index in selected) {
      final text = texts[index];
      final type =
          text.contains('每天') || text.contains('每日') || text.contains('习惯')
          ? GrowthType.habit
          : text.contains('学习') ||
                text.contains('课程') ||
                text.contains('阅读') ||
                text.contains('单词')
          ? GrowthType.learning
          : GrowthType.goal;
      growth.add(
        GrowthItem(
          id: 'imported-${DateTime.now().microsecondsSinceEpoch}-$index',
          title: text.length > 60 ? text.substring(0, 60) : text,
          type: type,
          area: '番茄ToDo导入',
          createdAt: DateTime.now(),
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已导入 ${selected.length} 项到成长模块')));
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
                  title: '番茄ToDo 页面导入',
                  subtitle: _captureEnabled == true
                      ? '页面导入已开启 · 仅在你点击「导入此页」时抓取'
                      : '开启后，番茄ToDo 页面会出现「导入此页」按钮',
                  children: [
                    Text(
                      '没有公开 API，所以采用显式抓取：打开番茄ToDo → 点击悬浮的「导入此页」→ 回到落·番茄预览并确认。不会持续读取屏幕，也不会读取密码。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.55,
                        color: context.surfaces.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await _capture.openSettings();
                              if (mounted) _loadStatuses();
                            },
                            child: Text(
                              _captureEnabled == true ? '无障碍设置' : '开启页面导入',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => const TargetAppService().launch(
                              settings.targetAppPackage,
                            ),
                            child: const Text('打开番茄ToDo'),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _checkPendingCapture,
                        child: const Text('检查已抓取内容'),
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
