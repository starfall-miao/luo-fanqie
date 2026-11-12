import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../focus/views/focus_page.dart';
import '../../settings/views/settings_page.dart';
import '../../stats/views/stats_page.dart';
import '../../sync/providers/sync_controller.dart';
import '../../tasks/views/tasks_page.dart';
import '../../timer/models/pomodoro_phase.dart';
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

  void _startFocusForTask(String taskId) {
    final timer = context.read<PomodoroController>();
    if (timer.isRunning) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('正在专注中，先暂停再切换任务')));
      _goTo(0);
      return;
    }
    if (timer.isPaused) timer.reset();
    if (timer.phase != PomodoroPhase.focus) {
      timer.switchPhase(PomodoroPhase.focus);
    }
    if (!timer.selectTask(taskId)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('找不到这颗任务了')));
      return;
    }
    timer.start();
    HapticFeedback.mediumImpact();
    _goTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final pages = <Widget>[
      const FocusPage(),
      TasksPage(onStartFocus: _startFocusForTask),
      const StatsPage(),
      const SettingsPage(),
    ];
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final content = IndexedStack(index: _index, children: pages);
            if (!wide) {
              return content;
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 8, 22),
                    child: SizedBox(
                      width: 184,
                      child: _SideRail(
                        index: _index,
                        onSelected: _goTo,
                        destinations: _destinations,
                      ),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            );
          },
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 980) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: surfaces.nav.withValues(alpha: 0.86),
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
                        child: Row(
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
                        ),
                      ),
                    ),
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

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.onSelected,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<_Destination> destinations;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: surfaces.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
            child: Row(
              children: [
                const TomatoMark(size: 34, withGlow: true),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '落·番茄',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'serif',
                        fontFamilyFallback: const [
                          'Songti SC',
                          'Noto Serif CJK SC',
                          'SimSun',
                        ],
                      ),
                    ),
                    Text(
                      '把时间种成番茄',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < destinations.length; i += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: i == index
                    ? scheme.primary.withValues(alpha: 0.11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          i == index
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          size: 20,
                          color: i == index ? scheme.primary : surfaces.muted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          destinations[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index ? scheme.primary : surfaces.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              '慢一点，也是在往前走。\n\nv1.2.1',
              style: TextStyle(
                height: 1.7,
                fontSize: 11,
                color: surfaces.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
