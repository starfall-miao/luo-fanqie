import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/tomato_mark.dart';
import '../../../tasks/models/task.dart';
import '../../../tasks/providers/task_controller.dart';
import '../../../timer/providers/pomodoro_controller.dart';

class _TaskChoice {
  const _TaskChoice(this.taskId);

  final String? taskId;
}

/// 从待办里挑一颗任务，绑定到本次专注。
Future<void> showFocusTaskPicker(BuildContext context) async {
  final timer = context.read<PomodoroController>();
  if (timer.isRunning) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('专注进行中，暂停后再更换任务')));
    return;
  }
  final choice = await showModalBottomSheet<_TaskChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _TaskPickerSheet(selectedTaskId: timer.selectedTaskId),
  );
  if (choice == null || !context.mounted) return;
  timer.selectTask(choice.taskId);
}

class _TaskPickerSheet extends StatelessWidget {
  const _TaskPickerSheet({required this.selectedTaskId});

  final String? selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskController>().pending;
    final surfaces = context.surfaces;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            const SizedBox(height: 22),
            Text('这次，专注于什么？', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 5),
            Text(
              '选一颗待办任务，收获的番茄会记在它名下。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _ChoiceTile(
                    leading: const _TileIcon(icon: Icons.all_inclusive_rounded),
                    title: '自由专注',
                    subtitle: '不关联任务，也很好',
                    selected: selectedTaskId == null,
                    onTap: () =>
                        Navigator.of(context).pop(const _TaskChoice(null)),
                  ),
                  for (final task in tasks)
                    _TaskChoiceTile(
                      task: task,
                      selected: task.id == selectedTaskId,
                      onTap: () =>
                          Navigator.of(context).pop(_TaskChoice(task.id)),
                    ),
                ],
              ),
            ),
            if (tasks.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaces.cardMuted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const TomatoMark(size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '待办还是空的。先去「任务」页种下一颗，再回来安心专注。',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: surfaces.muted, height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '剩余 ${tasks.length} 个待办 · 选一件，先开始',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: surfaces.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskChoiceTile extends StatelessWidget {
  const _TaskChoiceTile({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final Task task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scope = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scope.primary.withValues(alpha: context.isDark ? 0.16 : 0.08)
            : surfaces.cardMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppPalette.tagSoft(
                      task.tag,
                      Theme.of(context).brightness,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: 19,
                    color: AppPalette.tag(task.tag),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 7,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.tag.trim().isNotEmpty)
                            TagChip(label: task.tag, small: true),
                          Text(
                            '${task.kind.shortLabel} · ${task.focusMinutes} 分钟/次',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 11, color: surfaces.muted),
                          ),
                          if (task.hasTarget)
                            Text(
                              '· ${task.progressLabel(DateTime.now())}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 11,
                                    color: surfaces.muted,
                                  ),
                            )
                          else if (task.dueDate != null)
                            Text(
                              '· ${dueDateLabel(task.dueDate!)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 11,
                                    color: surfaces.muted,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scope.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? scope.primary : surfaces.faint,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: scope.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scope = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scope.primary.withValues(alpha: context.isDark ? 0.16 : 0.08)
            : surfaces.cardMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: scope.primary,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: scheme.primary),
    );
  }
}
