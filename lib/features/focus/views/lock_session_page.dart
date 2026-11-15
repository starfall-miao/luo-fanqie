import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/immersive/immersive_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../companion/luoluo_mascot.dart';
import '../../guard/views/app_whitelist_sheet.dart';
import '../../settings/providers/settings_controller.dart';

Future<void> openLockSession(
  BuildContext context, {
  required DateTime endAt,
  required int minutes,
  String title = '锁机',
}) async {
  if (!endAt.isAfter(DateTime.now())) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          LockSessionPage(endAt: endAt, minutes: minutes, title: title),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    ),
  );
}

class LockSessionPage extends StatefulWidget {
  const LockSessionPage({
    super.key,
    required this.endAt,
    required this.minutes,
    required this.title,
  });

  final DateTime endAt;
  final int minutes;
  final String title;

  static bool active = false;

  @override
  State<LockSessionPage> createState() => _LockSessionPageState();
}

class _LockSessionPageState extends State<LockSessionPage>
    with WidgetsBindingObserver {
  static const _immersive = ImmersiveModeService();

  Timer? _ticker;
  late DateTime _endAt;
  late int _remainingSeconds;
  bool _leaving = false;

  SettingsController get _settings => context.read<SettingsController>();

  int get _remainingExits => _settings.strictExitsRemaining;

  @override
  void initState() {
    super.initState();
    LockSessionPage.active = true;
    WidgetsBinding.instance.addObserver(this);
    _endAt = widget.endAt;
    _remainingSeconds = _endAt.difference(DateTime.now()).inSeconds;
    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishLock());
    } else {
      _startGuards();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  Future<void> _startGuards() async {
    final settings = _settings.settings;
    await _immersive.enter(keepScreenOn: false);
    if (settings.strictLockTask) {
      await _immersive.startLockTask();
    }
    if (settings.strictDnd) {
      await _immersive.startDnd();
    }
    if (settings.strictSnoozeNotifications) {
      await _immersive.startNotificationGuard(_endAt);
    }
    if (settings.strictOverlay) {
      await _immersive.startStrictGuard(
        endAt: _endAt,
        title: widget.title,
        whitelist: settings.whitelistPackages,
      );
    }
  }

  void _onTick() {
    final seconds = _endAt.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) {
      _finishLock();
      return;
    }
    if (mounted) setState(() => _remainingSeconds = seconds);
  }

  Future<void> _finishLock() async {
    if (_leaving) return;
    _leaving = true;
    _ticker?.cancel();
    await _immersive.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _exitEarly() async {
    if (_leaving) return;
    if (_remainingExits <= 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('这个月的锁机出口用完啦'),
          content: const Text('落落会把这一晚守完。系统设置和无障碍服务仍然可以随时关闭，这是留给你的安全出口。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('继续锁机'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '要提前打开手机吗？',
      message: '会消耗一次本月锁机退出机会，剩余 $_remainingExits 次。锁定和勿扰会立即解除。',
      confirmText: '打开手机',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _settings.consumeStrictExit();
    HapticFeedback.mediumImpact();
    await _finishLock();
  }

  Future<void> _openWhitelistedApps() async {
    await showWhitelistLauncher(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _onTick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    LockSessionPage.active = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_immersive.leave());
    super.dispose();
  }

  String get _countdown {
    final seconds = _remainingSeconds.clamp(0, 86400 * 2);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaces.canvasTop, surfaces.canvasBottom],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: AppPalette.tomato,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.tomato,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '剩余 $_remainingExits 次出口',
                        style: TextStyle(fontSize: 10.5, color: surfaces.faint),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(child: LuoLuoMascot(size: 150, studying: true)),
                  const SizedBox(height: 12),
                  Text(
                    '落落把手机收进小盒子啦',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '现在不是看手机的时候。闭上眼睛，或者把注意力交给呼吸。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: surfaces.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _countdown,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '计划锁机 ${widget.minutes} 分钟',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: surfaces.faint),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openWhitelistedApps,
                      icon: const Icon(Icons.apps_rounded, size: 17),
                      label: const Text('白名单应用'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _exitEarly,
                      icon: const Icon(Icons.lock_open_rounded, size: 17),
                      label: Text(
                        _remainingExits > 0
                            ? '提前打开手机（剩余 $_remainingExits 次）'
                            : '本月出口已用完',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
