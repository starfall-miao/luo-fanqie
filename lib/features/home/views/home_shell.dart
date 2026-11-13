import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../focus/views/focus_page.dart';
import '../../focus/views/session_page.dart';
import 'landscape_dashboard.dart';
import '../../settings/providers/settings_controller.dart';
import '../../settings/views/settings_page.dart';
import '../../stats/views/stats_page.dart';
import '../../sync/providers/sync_controller.dart';
import '../../tasks/views/tasks_page.dart';
import '../../tasks/models/task.dart';
import '../../timer/providers/pomodoro_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _destinations = <_Destination>[
    _Destination('专注', Icons.timer_outlined, Icons.timer_rounded),
    _Destination('任务', Icons.checklist_rounded, Icons.fact_check_rounded),
    _Destination('统计', Icons.insights_outlined, Icons.insights_rounded),
    _Destination('我的', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  int _index = 0;
  PomodoroController? _timer;
  SyncController? _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timer = context.read<PomodoroController>();
    if (identical(timer, _timer)) return;
    _timer?.justCompleted.removeListener(_onFocusCompleted);
    _timer = timer;
    timer.justCompleted.addListener(_onFocusCompleted);
    _sync = context.read<SyncController>();
  }

  @override
  void dispose() {
    _timer?.justCompleted.removeListener(_onFocusCompleted);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.syncTime();
      _sync?.syncOnResume();
    }
  }

  void _onFocusCompleted() {
    final completion = _timer?.consumeCompletion();
    if (completion == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const TomatoMark(size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                completion.task == null
                    ? '番茄落袋 · 专注 ${completion.phaseMinutes} 分钟'
                    : '「${completion.task!.title}」收获一颗番茄',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '看记录',
          onPressed: () {
            if (mounted) _goTo(2);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _goTo(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  Future<void> _startFocusForTask(Task task) async {
    final timer = context.read<PomodoroController>();
    if (timer.isRunning) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('正在专注中，先暂停再切换待办')));
      return;
    }
    await launchFocusSession(context, task: task, resetPaused: true);
  }

  Widget _navRow() {
    return Row(
      children: [
        for (var i = 0; i < _destinations.length; i += 1)
          Expanded(
            child: _NavItem(
              destination: _destinations[i],
              selected: i == _index,
              onTap: () => _goTo(i),
            ),
          ),
      ],
    );
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _SettingsScreen()));
  }

  void _openStats() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _StatsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final glass = context.select<SettingsController, bool>(
      (controller) => controller.settings.glassEffects,
    );
    final pages = <Widget>[
      const FocusPage(),
      TasksPage(onStartFocus: (task) => _startFocusForTask(task)),
      const StatsPage(),
      const SettingsPage(),
    ];
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth >= 900 &&
                constraints.maxWidth > constraints.maxHeight;
            if (landscape) {
              return LandscapeDashboard(
                onOpenSettings: _openSettings,
                onOpenStats: _openStats,
              );
            }
            return IndexedStack(index: _index, children: pages);
          },
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth >= 900 &&
                constraints.maxWidth > constraints.maxHeight;
            if (landscape) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: glass
                          ? surfaces.nav.withValues(alpha: 0.86)
                          : surfaces.nav,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: surfaces.border.withValues(alpha: 0.9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.isDark ? 0.3 : 0.08,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: glass
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: _navRow(),
                            ),
                          )
                        : _navRow(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: '返回',
                      size: 40,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.surfaces.muted,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Expanded(child: SettingsPage()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsScreen extends StatelessWidget {
  const _StatsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: '返回',
                      size: 40,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      '完整统计',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.surfaces.muted,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Expanded(child: StatsPage()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: context.isDark ? 0.18 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? scheme.primary : surfaces.muted,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : surfaces.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
