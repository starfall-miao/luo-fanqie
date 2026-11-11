import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/common.dart';
import '../../models/task.dart';
import '../../providers/task_controller.dart';

Future<void> showTaskEditor(BuildContext context, {Task? task}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (sheetContext) => _TaskEditorSheet(task: task),
  );
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({this.task});

  final Task? task;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late int _estimated;
  late TaskPriority _priority;
  late String _tag;
  DateTime? _dueDate;
  String? _titleError;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _estimated = task?.estimatedPomodoros ?? 1;
    _priority = task?.priority ?? TaskPriority.medium;
    _tag = task?.tag ?? '学习';
    _dueDate = task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: addDays(now, -365),
      lastDate: addDays(now, 365),
      helpText: '选择截止日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _dueDate = startOfDay(picked));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '先写下要完成的事，再种下它');
      return;
    }
    final controller = context.read<TaskController>();
    final notes = _notesController.text.trim();
    if (_isEditing) {
      controller.update(
        widget.task!.copyWith(
          title: title,
          notes: notes,
          estimatedPomodoros: _estimated,
          priority: _priority,
          tag: _tag,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
        ),
      );
    } else {
      controller.add(
        Task(
          id: newId('task'),
          title: title,
          notes: notes,
          estimatedPomodoros: _estimated,
          priority: _priority,
          tag: _tag,
          dueDate: _dueDate,
          createdAt: DateTime.now(),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '拔掉这颗任务？',
      message: '删除后无法恢复，已经收获的番茄记录会保留。',
      confirmText: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    context.read<TaskController>().remove(widget.task!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? '编辑任务' : '种下一颗新任务',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: '删除任务',
                    onPressed: _delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '比如：写完项目复盘',
                counterText: '',
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: '补充一点细节（可选）',
                counterText: '',
              ),
            ),
            const SizedBox(height: 22),
            const _FieldLabel(title: '预计番茄', hint: '一颗番茄专注 25 分钟'),
            const SizedBox(height: 10),
            _EstimateStepper(
              value: _estimated,
              onChanged: (value) => setState(() => _estimated = value),
            ),
            const SizedBox(height: 22),
            const _FieldLabel(title: '优先级'),
            const SizedBox(height: 10),
            _PriorityPicker(
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 22),
            const _FieldLabel(title: '分类'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in kTaskTags)
                  _TagChoice(
                    label: tag,
                    selected: _tag == tag,
                    onTap: () => setState(() => _tag = tag),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const _FieldLabel(title: '截止日期'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DateChoice(
                  label: '不设置',
                  selected: _dueDate == null,
                  onTap: () => setState(() => _dueDate = null),
                ),
                _DateChoice(
                  label: '今天',
                  selected: _dueDate != null && isToday(_dueDate!),
                  onTap: () =>
                      setState(() => _dueDate = startOfDay(DateTime.now())),
                ),
                _DateChoice(
                  label: '明天',
                  selected:
                      _dueDate != null &&
                      isSameDay(_dueDate!, addDays(DateTime.now(), 1)),
                  onTap: () =>
                      setState(() => _dueDate = addDays(DateTime.now(), 1)),
                ),
                _DateChoice(
                  label:
                      _dueDate == null ||
                          isToday(_dueDate!) ||
                          isSameDay(_dueDate!, addDays(DateTime.now(), 1))
                      ? '选日期'
                      : '${_dueDate!.month}月${_dueDate!.day}日',
                  selected:
                      _dueDate != null &&
                      !isToday(_dueDate!) &&
                      !isSameDay(_dueDate!, addDays(DateTime.now(), 1)),
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? '保存修改' : '种下这颗任务'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: surfaces.muted,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Text(hint!, style: TextStyle(fontSize: 10.5, color: surfaces.faint)),
        ],
      ],
    );
  }
}

class _EstimateStepper extends StatelessWidget {
  const _EstimateStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: surfaces.cardMuted.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_florist_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: context.onSurface,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '颗',
                  style: TextStyle(fontSize: 13, color: surfaces.muted),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: value < 12 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Material(
      color: surfaces.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: surfaces.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? surfaces.faint : surfaces.muted,
          ),
        ),
      ),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  Color _color(TaskPriority priority) => switch (priority) {
    TaskPriority.low => AppPalette.sage,
    TaskPriority.medium => AppPalette.apricot,
    TaskPriority.high => AppPalette.tomato,
  };

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      children: [
        for (final priority in [
          TaskPriority.low,
          TaskPriority.medium,
          TaskPriority.high,
        ])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: priority == TaskPriority.high ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () => onChanged(priority),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == priority
                        ? _color(priority).withValues(alpha: 0.12)
                        : surfaces.cardMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: value == priority
                          ? _color(priority).withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _color(priority),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${priority.label}优先',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: value == priority
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: value == priority
                              ? _color(priority)
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
    );
  }
}

class _TagChoice extends StatelessWidget {
  const _TagChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.tag(label);
    final surfaces = context.surfaces;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: context.isDark ? 0.22 : 0.12)
              : surfaces.cardMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? color : surfaces.muted,
          ),
        ),
      ),
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: context.isDark ? 0.22 : 0.10)
              : surfaces.cardMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? scheme.primary : surfaces.muted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.primary : surfaces.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
