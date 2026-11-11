import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../timer/providers/pomodoro_controller.dart';
import '../models/task.dart';
import '../providers/task_controller.dart';
import 'widgets/task_editor_sheet.dart';

enum _TaskFilter { all, pending, completed }

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, this.onStartFocus});

  final ValueChanged<String>? onStartFocus;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    final selectedTaskId = context.select<PomodoroController, String?>(
      (timer) => timer.selectedTaskId,
    );
    final tasks = controller.sorted;
    final visible = switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.pending => tasks.where((task) => !task.done).toList(),
      _TaskFilter.completed => tasks.where((task) => task.done).toList(),
    };

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: '番茄田',
                  title: '一棵一棵，慢慢长大',
                  subtitle: '把想做的事拆小一点，然后认真完成它。',
                  trailing: CircleIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '新建任务',
                    size: 48,
                    filled: true,
                    onPressed: () => showTaskEditor(context),
                  ),
                ),
                const SizedBox(height: 20),
                _SummaryCard(controller: controller),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _FilterPill(
                      label: '全部',
                      count: tasks.length,
                      selected: _filter == _TaskFilter.all,
                      onTap: () => setState(() => _filter = _TaskFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: '待办',
                      count: controller.pendingCount,
                      selected: _filter == _TaskFilter.pending,
                      onTap: () =>
                          setState(() => _filter = _TaskFilter.pending),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: '完成',
                      count: tasks.length - controller.pendingCount,
                      selected: _filter == _TaskFilter.completed,
                      onTap: () =>
                          setState(() => _filter = _TaskFilter.completed),
                    ),
                    const Spacer(),
                    Text(
                      '优先级排序',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.surfaces.faint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  _EmptyTasks(filter: _filter)
                else
                  for (var i = 0; i < visible.length; i += 1) ...[
                    _TaskTile(
                      task: visible[i],
                      selected: visible[i].id == selectedTaskId,
                      onTap: () => showTaskEditor(context, task: visible[i]),
                      onStart: widget.onStartFocus == null
                          ? null
                          : () => widget.onStartFocus!(visible[i].id),
                    ),
                    if (i != visible.length - 1) const SizedBox(height: 10),
                  ],
                if (visible.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      visible.every((task) => task.done)
                          ? '今天的番茄都收好啦，明天见。'
                          : '一次只做一件事，就已经很好。',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        color: context.surfaces.faint,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final TaskController controller;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      radius: 22,
      child: Row(
        children: [
          _SummaryItem(
            value: '${controller.pendingCount}',
            label: '进行中',
            color: Theme.of(context).colorScheme.primary,
          ),
          _Divider(color: surfaces.border),
          _SummaryItem(
            value: '${controller.pendingEstimatedPomodoros}',
            label: '预计番茄',
            color: AppPalette.apricot,
          ),
          _Divider(color: surfaces.border),
          _SummaryItem(
            value: '${controller.completedTodayCount}',
            label: '今日完成',
            color: AppPalette.sage,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: context.surfaces.muted),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: color.withValues(alpha: 0.7));
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: context.isDark ? 0.22 : 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : surfaces.border.withValues(alpha: 0.8),
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : surfaces.muted,
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.selected,
    required this.onTap,
    this.onStart,
  });

  final Task task;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onStart;

  Color _priorityColor(BuildContext context) => switch (task.priority) {
    TaskPriority.high => AppPalette.tomato,
    TaskPriority.medium => AppPalette.apricot,
    TaskPriority.low => AppPalette.sage,
  };

  void _toggleDone(BuildContext context) {
    HapticFeedback.lightImpact();
    context.read<TaskController>().toggleDone(task.id);
  }

  void _remove(BuildContext context) {
    final controller = context.read<TaskController>();
    final messenger = ScaffoldMessenger.of(context);
    final removed = controller.remove(task.id);
    if (removed == null) return;
    HapticFeedback.mediumImpact();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已拔掉「${removed.title}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => controller.insert(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final overdue = task.isOverdue();
    return Dismissible(
      key: ValueKey<String>(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context),
      background: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: scheme.error, size: 22),
            const SizedBox(height: 3),
            Text(
              '删除',
              style: TextStyle(
                color: scheme.error,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: task.done ? 0.72 : 1,
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          radius: 22,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _TaskCheckbox(
                  done: task.done,
                  priorityColor: _priorityColor(context),
                  onTap: () => _toggleDone(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: task.done
                                  ? surfaces.muted
                                  : context.onSurface,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: surfaces.faint,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '当前专注任务',
                            child: Icon(
                              Icons.timer_rounded,
                              size: 15,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                        if (task.priority == TaskPriority.high &&
                            !task.done) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '高优先级',
                            child: Icon(
                              Icons.flag_rounded,
                              size: 14,
                              color: _priorityColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.notes.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TagChip(label: task.tag, small: true),
                        if (overdue)
                          _MetaBadge(
                            label: '逾期',
                            icon: Icons.error_outline_rounded,
                            color: scheme.error,
                          )
                        else if (task.dueDate != null)
                          _MetaBadge(
                            label: dueDateLabel(task.dueDate!),
                            icon: Icons.event_rounded,
                            color: isToday(task.dueDate!)
                                ? scheme.primary
                                : surfaces.muted,
                          ),
                        _MetaBadge(
                          label:
                              '${task.completedPomodoros}/${task.estimatedPomodoros}',
                          icon: Icons.local_florist_rounded,
                          color:
                              task.completedPomodoros >= task.estimatedPomodoros
                              ? AppPalette.sage
                              : surfaces.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!task.done && onStart != null) ...[
                const SizedBox(width: 8),
                _StartFocusButton(onTap: onStart!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StartFocusButton extends StatelessWidget {
  const _StartFocusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '开始专注这颗任务',
      child: Material(
        color: scheme.primary.withValues(alpha: context.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 17, color: scheme.primary),
                const SizedBox(height: 2),
                Text(
                  '开始',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({
    required this.done,
    required this.priorityColor,
    required this.onTap,
  });

  final bool done;
  final Color priorityColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: done,
      button: true,
      label: done ? '标记为未完成' : '标记为完成',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppPalette.sage : Colors.transparent,
            border: Border.all(
              color: done
                  ? AppPalette.sage
                  : priorityColor.withValues(alpha: 0.75),
              width: 1.6,
            ),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: done ? 1 : 0,
            child: Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.5, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: color)),
      ],
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.filter});

  final _TaskFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (filter) {
      _TaskFilter.all => ('番茄田还是空的', '种下第一颗任务，让它和一个番茄一起长大。'),
      _TaskFilter.pending => ('待办都完成啦', '给自己倒杯水，或者再种下一颗新的种子。'),
      _TaskFilter.completed => ('还没有完成的任务', '完成的番茄会安静地躺在这里，等你回来看看。'),
    };
    return SoftCard(
      radius: 26,
      padding: EdgeInsets.zero,
      child: EmptyState(
        title: title,
        message: message,
        action: filter == _TaskFilter.completed
            ? null
            : FilledButton.icon(
                onPressed: () => showTaskEditor(context),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('种下一颗任务'),
              ),
      ),
    );
  }
}
