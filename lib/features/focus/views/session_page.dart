import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/immersive/immersive_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tomato_mark.dart';
import '../../settings/providers/settings_controller.dart';
import '../../soundscape/soundscape_controller.dart';
import '../../stats/providers/stats_controller.dart';
import '../../tasks/models/task.dart';
import '../../timer/models/pomodoro_phase.dart';
import '../../timer/providers/pomodoro_controller.dart';
import '../../timer/theme/phase_style.dart';
import 'widgets/timer_dial.dart';

const _quotes = <String>[
  '没有过不去的坎，只有过不去的心情。',
  '把注意力放回此刻，时间会给你答案。',
  '你只管努力，剩下的交给时间。',
  '慢慢来，比较快。',
  '一颗番茄，也是一次对未来的投票。',
  '此刻的安静，会长成你想要的样子。',
];

Future<void> launchFocusSession(
  BuildContext context, {
  Task? task,
  bool resetPaused = false,
}) async {
  if (!context.mounted) return;
  final timer = context.read<PomodoroController>();
  final settings = context.read<SettingsController>().settings;
  if (timer.isRunning) {
    await _openSession(context, strict: settings.strictMode);
    return;
  }
  if (timer.isPaused && resetPaused) timer.reset();
  if (timer.phase != PomodoroPhase.focus) {
    timer.switchPhase(PomodoroPhase.focus);
  }
  if (task != null) {
    timer.selectTask(task.id);
  }
  final minutes = task?.focusMinutes ?? timer.selectedTask?.focusMinutes;
  timer.start(focusMinutes: minutes);
  HapticFeedback.mediumImpact();
  if (!context.mounted) return;
  await _openSession(context, strict: settings.strictMode);
}

Future<void> _openSession(BuildContext context, {required bool strict}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          SessionPage(strict: strict),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.02, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.strict});

  final bool strict;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  static const _immersive = ImmersiveModeService();

  PomodoroController? _timer;
  SoundscapeController? _soundscape;
  late final String _quote;
  late int _lastCompletedInCycle;
  bool _completed = false;
  bool _finishing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[DateTime.now().millisecondsSinceEpoch % _quotes.length];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _soundscape ??= context.read<SoundscapeController>();
    final timer = context.read<PomodoroController>();
    if (identical(timer, _timer)) return;
    _timer?.removeListener(_handleTimer);
    _timer = timer;
    _lastCompletedInCycle = timer.completedInCycle;
    timer.addListener(_handleTimer);
    unawaited(_immersive.enter(lockTask: widget.strict));
  }

  void _handleTimer() {
    final timer = _timer;
    if (timer == null || _completed) return;
    if (timer.completedInCycle > _lastCompletedInCycle) {
      _lastCompletedInCycle = timer.completedInCycle;
      setState(() => _completed = true);
      unawaited(_immersive.leave());
    }
  }

  Future<void> _minimize() async {
    if (widget.strict) return;
    Navigator.of(context).pop();
  }

  Future<void> _finish({bool emergency = false}) async {
    if (_finishing) return;
    final confirmed = await showConfirmDialog(
      context,
      title: emergency ? '结束学霸模式？' : '提前结束这次专注？',
      message: emergency
          ? '本轮专注不会计入番茄记录，屏幕固定会解除。'
          : '结束本轮不会计入番茄记录，休息时间可以从首页重新开始。',
      confirmText: '结束本轮',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _finishing = true;
    _allowPop = true;
    _timer?.reset();
    await _immersive.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showSounds() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _SoundscapeSheet(),
    );
  }

  Future<void> _showTools() async {
    final timer = _timer!;
    final stats = context.read<StatsController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.surfaces.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('专注小工具', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            _ToolRow(
              icon: Icons.timer_outlined,
              title: '本轮专注',
              subtitle: '${timer.remainingLabel} · ${timer.phase.label}',
            ),
            _ToolRow(
              icon: Icons.local_florist_rounded,
              title: '今日收获',
              subtitle: '${stats.todaySessions} 颗番茄 · ${stats.todayMinutes} 分钟',
            ),
            _ToolRow(
              icon: Icons.graphic_eq_rounded,
              title: '环境音',
              subtitle: '雨声、海浪与篝火，全部离线',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showSounds();
              },
            ),
            _ToolRow(
              icon: Icons.shield_outlined,
              title: '学霸模式',
              subtitle: widget.strict ? '已开启 · 系统屏幕固定中' : '未开启',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!widget.strict)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _minimize();
                      },
                      icon: const Icon(Icons.vertical_align_bottom_rounded),
                      label: const Text('最小化'),
                    ),
                  ),
                if (!widget.strict) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _finish(emergency: widget.strict);
                    },
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(widget.strict ? '结束锁机' : '结束本轮'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.removeListener(_handleTimer);
    unawaited(_soundscape?.stop() ?? Future<void>.value());
    unawaited(_immersive.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<PomodoroController>();
    final task = timer.selectedTask;
    final strict = widget.strict;
    final canPop = !strict || _completed || _allowPop;
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _SessionBackground(
          phase: timer.phase,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                final dialSize = math.min(
                  wide ? 360.0 : 310.0,
                  math.min(
                    constraints.maxWidth * (wide ? 0.38 : 0.82),
                    constraints.maxHeight * 0.55,
                  ),
                );
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 42 : 20,
                    wide ? 24 : 14,
                    wide ? 42 : 20,
                    26,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SessionTopBar(
                            strict: strict,
                            completed: _completed,
                            onMinimize: _minimize,
                            onTools: _showTools,
                            onSounds: _showSounds,
                          ),
                          const SizedBox(height: 20),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _SessionQuote(
                                    quote: _quote,
                                    task: task,
                                    strict: strict,
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: _SessionCenter(
                                    timer: timer,
                                    completed: _completed,
                                    strict: strict,
                                    dialSize: dialSize,
                                    onPause: timer.toggle,
                                    onFinish: () => _finish(emergency: strict),
                                    onMinimize: _minimize,
                                    onTools: _showTools,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _SessionQuote(
                              quote: _quote,
                              task: task,
                              strict: strict,
                            ),
                            const SizedBox(height: 10),
                            _SessionCenter(
                              timer: timer,
                              completed: _completed,
                              strict: strict,
                              dialSize: dialSize,
                              onPause: timer.toggle,
                              onFinish: () => _finish(emergency: strict),
                              onMinimize: _minimize,
                              onTools: _showTools,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionBackground extends StatelessWidget {
  const _SessionBackground({required this.phase, required this.child});

  final PomodoroPhase phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final visuals = visualsFor(phase);
    final baseTop = dark ? const Color(0xFF171014) : const Color(0xFFFFF5ED);
    final baseBottom = dark ? const Color(0xFF24140F) : const Color(0xFFFFE6D7);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseTop, baseBottom],
            ),
          ),
        ),
        Positioned(
          top: -160,
          right: -100,
          child: _glow(
            visuals.gradient.first.withValues(alpha: dark ? 0.26 : 0.3),
            440,
          ),
        ),
        Positioned(
          bottom: -180,
          left: -120,
          child: _glow(
            visuals.gradient.last.withValues(alpha: dark ? 0.2 : 0.24),
            420,
          ),
        ),
        child,
      ],
    );
  }

  Widget _glow(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _SessionTopBar extends StatelessWidget {
  const _SessionTopBar({
    required this.strict,
    required this.completed,
    required this.onMinimize,
    required this.onTools,
    required this.onSounds,
  });

  final bool strict;
  final bool completed;
  final VoidCallback onMinimize;
  final VoidCallback onTools;
  final VoidCallback onSounds;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      children: [
        if (!strict)
          CircleIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: '最小化，继续计时',
            onPressed: onMinimize,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppPalette.tomato.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_moon_outlined,
                  size: 14,
                  color: AppPalette.tomato,
                ),
                const SizedBox(width: 5),
                Text(
                  completed ? '本轮完成' : '学霸模式',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.tomato,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        Text(
          '落·番茄',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            letterSpacing: 1.6,
            fontSize: 13,
            color: surfaces.muted,
          ),
        ),
        const Spacer(),
        CircleIconButton(
          icon: Icons.graphic_eq_rounded,
          tooltip: '环境音',
          onPressed: onSounds,
        ),
        const SizedBox(width: 8),
        CircleIconButton(
          icon: Icons.grid_view_rounded,
          tooltip: '专注小工具',
          onPressed: onTools,
        ),
      ],
    );
  }
}

class _SessionQuote extends StatelessWidget {
  const _SessionQuote({
    required this.quote,
    required this.task,
    required this.strict,
  });

  final String quote;
  final Task? task;
  final bool strict;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 26,
              height: 1.5,
              letterSpacing: 0.4,
              color: context.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          if (task != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: surfaces.card.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: surfaces.border.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_florist_rounded,
                    size: 15,
                    color: AppPalette.tomato,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      task!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: surfaces.muted),
                    ),
                  ),
                ],
              ),
            ),
          if (strict) ...[
            const SizedBox(height: 12),
            Text(
              '已开启学霸模式：本轮结束前不能暂停或最小化，可使用系统手势退出屏幕固定。',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: surfaces.faint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCenter extends StatelessWidget {
  const _SessionCenter({
    required this.timer,
    required this.completed,
    required this.strict,
    required this.dialSize,
    required this.onPause,
    required this.onFinish,
    required this.onMinimize,
    required this.onTools,
  });

  final PomodoroController timer;
  final bool completed;
  final bool strict;
  final double dialSize;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onMinimize;
  final VoidCallback onTools;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final stats = context.watch<StatsController>();
    if (completed) {
      return Column(
        children: [
          const TomatoMark(size: 82, withGlow: true),
          const SizedBox(height: 16),
          Text('番茄落袋啦', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 7),
          Text(
            '今天已经收获 ${stats.todaySessions} 颗番茄 · ${stats.todayMinutes} 分钟',
            style: TextStyle(fontSize: 12, color: surfaces.muted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 210,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('回到番茄田'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        TimerDial(
          phase: timer.phase,
          status: timer.status,
          progress: timer.progress,
          remainingLabel: timer.remainingLabel,
          roundNumber: timer.roundNumber,
          rounds: timer.roundsPerLongBreak,
          completedInCycle: timer.completedInCycle,
          taskTitle: timer.selectedTask?.title,
          maxSize: dialSize,
        ),
        const SizedBox(height: 18),
        if (!strict)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleIconButton(
                icon: Icons.vertical_align_bottom_rounded,
                tooltip: '最小化',
                onPressed: onMinimize,
              ),
              const SizedBox(width: 18),
              _PrimaryRoundButton(
                icon: timer.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: onPause,
              ),
              const SizedBox(width: 18),
              CircleIconButton(
                icon: Icons.stop_rounded,
                tooltip: '结束本轮',
                onPressed: onFinish,
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onTools,
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('小工具'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('结束锁机'),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          strict ? '保持专注，屏幕已固定' : '离开这个页面，计时也会继续',
          style: TextStyle(fontSize: 10.5, color: surfaces.faint),
        ),
      ],
    );
  }
}

class _PrimaryRoundButton extends StatelessWidget {
  const _PrimaryRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: icon == Icons.pause_rounded ? '暂停' : '继续',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                scheme.primary,
                AppPalette.apricot.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.3),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(icon, size: 36, color: Colors.white),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, size: 17, color: surfaces.faint),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: context.primary),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: surfaces.faint),
      ),
    );
  }
}

class _SoundscapeSheet extends StatelessWidget {
  const _SoundscapeSheet();

  @override
  Widget build(BuildContext context) {
    final sound = context.watch<SoundscapeController>();
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
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
          Text('环境音', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            '全部音频随应用打包，不依赖网络，也不会上传任何信息。',
            style: TextStyle(fontSize: 11, color: surfaces.faint),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final scene in Soundscape.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: scene == Soundscape.fire ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () => sound.toggle(scene),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: sound.active == scene
                              ? scheme.primary.withValues(alpha: 0.12)
                              : surfaces.cardMuted.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sound.active == scene
                                ? scheme.primary.withValues(alpha: 0.45)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              switch (scene) {
                                Soundscape.rain => Icons.water_drop_outlined,
                                Soundscape.waves => Icons.waves_rounded,
                                Soundscape.fire =>
                                  Icons.local_fire_department_outlined,
                              },
                              size: 22,
                              color: sound.active == scene
                                  ? scheme.primary
                                  : surfaces.muted,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              scene.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: sound.active == scene
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: sound.active == scene
                                    ? scheme.primary
                                    : surfaces.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.volume_down_rounded, size: 17, color: surfaces.faint),
              Expanded(
                child: Slider(value: sound.volume, onChanged: sound.setVolume),
              ),
              Icon(Icons.volume_up_rounded, size: 17, color: surfaces.faint),
            ],
          ),
          if (sound.active != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sound.stop,
                icon: const Icon(Icons.stop_rounded, size: 17),
                label: const Text('停止环境音'),
              ),
            ),
          if (sound.error != null) ...[
            const SizedBox(height: 10),
            Text(
              sound.error!,
              style: TextStyle(fontSize: 11, color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
