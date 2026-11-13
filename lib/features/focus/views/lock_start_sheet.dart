import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_controller.dart';
import 'session_page.dart';

Future<void> showLockStartSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _LockStartSheet(
      onStart: (minutes) {
        launchFocusSession(
          context,
          focusMinutes: minutes,
          strictOverride: true,
          resetPaused: true,
        );
      },
    ),
  );
}

class _LockStartSheet extends StatefulWidget {
  const _LockStartSheet({required this.onStart});

  final ValueChanged<int> onStart;

  @override
  State<_LockStartSheet> createState() => _LockStartSheetState();
}

class _LockStartSheetState extends State<_LockStartSheet> {
  int _minutes = 45;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
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
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.lock_clock_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '落落要把门关上啦',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '这段时间只做一件事。每月有 3 次提前退出机会。',
                      style: TextStyle(fontSize: 11.5, color: surfaces.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '锁机时长',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: surfaces.muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in [25, 45, 60, 90, 120])
                ChoiceChip(
                  label: Text('$minutes 分钟'),
                  selected: _minutes == minutes,
                  onSelected: (_) => setState(() => _minutes = minutes),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaces.cardMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: surfaces.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '强制自控选项会按设置生效：置顶提醒、锁定任务、静音通知、应用白名单。开始后会进入沉浸专注页。',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      color: surfaces.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('今天先不锁'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    navigator.pop();
                    if (!settings.settings.strictMode) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('锁机默认使用严格界面，可在设置中打开置顶/锁定任务'),
                          ),
                        );
                    }
                    widget.onStart(_minutes);
                  },
                  icon: const Icon(Icons.lock_rounded, size: 17),
                  label: const Text('开始锁机'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
