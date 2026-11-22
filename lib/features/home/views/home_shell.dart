import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../focus/views/focus_page.dart';
import '../../focus/views/lock_session_page.dart';
import '../../focus/views/session_page.dart';
import '../../guard/services/auto_lock_service.dart';
import '../../guard/views/guard_page.dart';
import '../../growth/views/growth_page.dart';
import '../../settings/providers/settings_controller.dart';
import '../../settings/views/settings_page.dart';
import '../../stats/views/stats_page.dart';
import '../../sync/providers/sync_controller.dart';
import '../../tasks/views/tasks_page.dart';
import '../../tasks/models/task.dart';
import '../../timer/providers/pomodoro_controller.dart';
import '../../today/views/today_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _destinations = <_Destination>[
    _Destination('今日', Icons.today_outlined, Icons.today_rounded),
    _Destination('成长', Icons.trending_up_rounded, Icons.trending_up_rounded),
    _Destination('守护', Icons.shield_outlined, Icons.shield_rounded),
    _Destination('数据', Icons.insights_outlined, Icons.insights_rounded),
    _Destination('我的', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  int _index = 0;
  PomodoroController? _timer;
  SyncController? _sync;
  SettingsController? _settings;
  Timer? _autoLockTimer;
  bool _initialAutoLockChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsController>();
    if (!identical(settings, _settings)) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = settings;
      settings.addListener(_onSettingsChanged);
    }
    final timer = context.read<PomodoroController>();
    if (!identical(timer, _timer)) {
      _timer?.justCompleted.removeListener(_onFocusCompleted);
      _timer = timer;
      timer.justCompleted.addListener(_onFocusCompleted);
      _sync = context.read<SyncController>();
    }
    _scheduleAutoLock();
    _syncNativeAutoLock();
    if (!_initialAutoLockChecked) {
      _initialAutoLockChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAutoLock();
      });
    }
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    _settings?.removeListener(_onSettingsChanged);
    _timer?.justCompleted.removeListener(_onFocusCompleted);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.syncTime();
      _sync?.syncOnResume();
      _checkAutoLock();
    }
  }

  void _onSettingsChanged() {
    _scheduleAutoLock();
    _syncNativeAutoLock();
  }

  void _syncNativeAutoLock() {
    final settings = _settings?.settings;
    if (settings == null) return;
    const service = AutoLockService();
    if (settings.autoLockEnabled) {
      service.schedule(
        hour: settings.autoLockHour,
        minute: settings.autoLockMinute,
      );
    } else {
      service.cancel();
    }
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _scheduleAutoLock() {
    _autoLockTimer?.cancel();
    final settings = _settings;
    if (settings == null || !settings.settings.autoLockEnabled) return;
    final next = settings.nextAutoLockTime();
    if (next == null) return;
    final delay = next.difference(DateTime.now());
    _autoLockTimer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      _checkAutoLock,
    );
  }

  void _checkAutoLock() {
    final settingsController = _settings;
    if (!mounted || settingsController == null) return;
    final settings = settingsController.settings;
    if (!settings.autoLockEnabled) return;
    final now = DateTime.now();
    if (settings.autoLockLastDate == _dayKey(now)) {
      _scheduleAutoLock();
      return;
    }
    final due = DateTime(
      now.year,
      now.month,
      now.day,
      settings.autoLockHour,
      settings.autoLockMinute,
    );
    if (now.isBefore(due)) {
      _scheduleAutoLock();
      return;
    }
    final endAt = due.add(Duration(minutes: settings.autoLockMinutes));
    if (!now.isBefore(endAt)) {
      settingsController.markAutoLockStarted(now);
      _scheduleAutoLock();
      return;
    }
    final timer = _timer;
    if (timer == null || timer.isRunning || timer.isPaused) {
      settingsController.markAutoLockStarted(now);
      _scheduleAutoLock();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('锁机时间到，但当前已有专注在进行')));
      return;
    }
    if (LockSessionPage.active) {
      _scheduleAutoLock();
      return;
    }
    settingsController.markAutoLockStarted(now);
    HapticFeedback.mediumImpact();
    unawaited(
      openLockSession(
        context,
        endAt: endAt,
        minutes: settings.autoLockMinutes,
        title: '睡眠 / 时段锁机',
      ),
    );
    _scheduleAutoLock();
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
            if (mounted) _goTo(3);
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

  void _openFocus() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _FocusScreen()));
  }

  void _openTasks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TasksScreen(onStartFocus: _startFocusForTask),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final pages = <Widget>[
      TodayPage(
        onOpenGrowth: () => _goTo(1),
        onOpenGuard: () => _goTo(2),
        onOpenFocus: _openFocus,
        onOpenTasks: _openTasks,
      ),
      const GrowthPage(),
      GuardPage(onOpenSettings: _openSettings),
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
              return Row(
                children: [
                  _SideNav(
                    destinations: _destinations,
                    index: _index,
                    onSelected: _goTo,
                  ),
                  Expanded(child: pages[_index.clamp(0, pages.length - 1)]),
                ],
              );
            }
            return pages[_index.clamp(0, pages.length - 1)];
          },
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth >= 900 &&
                constraints.maxWidth > constraints.maxHeight;
            if (landscape) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                color: surfaces.nav,
                border: Border(top: BorderSide(color: surfaces.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(height: 62, child: _navRow()),
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

class _FocusScreen extends StatelessWidget {
  const _FocusScreen();

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
                      '计时与待办',
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
              const Expanded(child: FocusPage()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasksScreen extends StatelessWidget {
  const _TasksScreen({required this.onStartFocus});

  final ValueChanged<Task> onStartFocus;

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
                      '全部待办',
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
              Expanded(child: TasksPage(onStartFocus: onStartFocus)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Container(
      width: 196,
      decoration: BoxDecoration(
        color: surfaces.nav,
        border: Border(right: BorderSide(color: surfaces.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text('落·番茄', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            for (var i = 0; i < destinations.length; i += 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: i == index
                          ? Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          i == index
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          size: 19,
                          color: i == index
                              ? Theme.of(context).colorScheme.primary
                              : surfaces.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          destinations[i].label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == index
                                ? Theme.of(context).colorScheme.primary
                                : surfaces.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '番茄 ToDo 增强工作台',
                style: TextStyle(fontSize: 10, color: surfaces.faint),
              ),
            ),
          ],
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
