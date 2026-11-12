import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/common.dart';
import '../../../settings/providers/settings_controller.dart';
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
  late final TextEditingController _tagController;
  late final TextEditingController _targetController;
  late final TextEditingController _customUnitController;
  late final TextEditingController _monthDaysController;
  late TaskKind _kind;
  late int _focusMinutes;
  late TaskPriority _priority;
  late TaskUnit _targetUnit;
  late HabitSchedule _habitSchedule;
  final Set<int> _weekdays = <int>{};
  late DateTime? _dueDate;
  String? _error;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final settings = context.read<SettingsController>().settings;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _tagController = TextEditingController(text: task?.tag ?? '');
    _kind = task?.kind ?? TaskKind.pomodoro;
    _focusMinutes = task?.focusMinutes ?? settings.focusMinutes;
    _priority = task?.priority ?? TaskPriority.medium;
    _targetUnit = task?.targetUnit ?? TaskUnit.times;
    _customUnitController = TextEditingController(text: task?.customUnit ?? '');
    _targetController = TextEditingController(
      text: task?.targetAmount == null
          ? ''
          : _formatAmount(task!.targetAmount!),
    );
    _habitSchedule = task?.habitSchedule ?? HabitSchedule.daily;
    _weekdays.addAll(
      task?.weekdays ??
          (task?.habitSchedule == HabitSchedule.weekdays ? <int>[] : <int>[]),
    );
    _dueDate = task?.dueDate;
    _monthDaysController = TextEditingController(
      text: (task?.monthDays ?? const <int>[]).join(', '),
    );
    if (_kind == TaskKind.goal && _dueDate == null) {
      _dueDate = addDays(DateTime.now(), 7);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    _targetController.dispose();
    _customUnitController.dispose();
    _monthDaysController.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  List<int> _parseMonthDays() {
    return _monthDaysController.text
        .split(RegExp(r'[,，、\s]+'))
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .where((day) => day >= 1 && day <= 31)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: addDays(now, -365),
      lastDate: addDays(now, 365 * 3),
      helpText: _kind == TaskKind.goal ? '选择目标日期' : '选择截止日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _dueDate = startOfDay(picked));
  }

  void _changeKind(TaskKind kind) {
    setState(() {
      _kind = kind;
      _error = null;
      if (kind == TaskKind.habit) {
        _dueDate = null;
      } else if (kind == TaskKind.goal && _dueDate == null) {
        _dueDate = addDays(DateTime.now(), 7);
      }
      if (kind == TaskKind.habit && _targetUnit == TaskUnit.times) {
        _targetUnit = TaskUnit.minutes;
        _targetController.text = '30';
      }
    });
  }

  double? _targetValue() {
    final raw = _targetController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '先写下待办的名字');
      return;
    }
    final target = _kind == TaskKind.pomodoro ? null : _targetValue();
    if (_kind != TaskKind.pomodoro && target == null) {
      setState(() => _error = '请设置一个大于 0 的目标量');
      return;
    }
    if (_targetUnit == TaskUnit.custom &&
        _customUnitController.text.trim().isEmpty) {
      setState(() => _error = '请填写自定义单位');
      return;
    }
    final monthDays = _parseMonthDays();
    if (_kind == TaskKind.habit &&
        _habitSchedule == HabitSchedule.weekdays &&
        _weekdays.isEmpty) {
      setState(() => _error = '至少选择一天');
      return;
    }
    if (_kind == TaskKind.habit &&
        _habitSchedule == HabitSchedule.monthDays &&
        monthDays.isEmpty) {
      setState(() => _error = '请填写每月日期，例如 1, 5, 15');
      return;
    }
    final controller = context.read<TaskController>();
    final notes = _notesController.text.trim();
    final tag = _tagController.text.trim();
    final now = DateTime.now();
    final isHabit = _kind == TaskKind.habit;
    final weekdayList = _weekdays.toList()..sort();
    final unit = _targetUnit;
    final customUnit = _customUnitController.text.trim();
    final progressPeriodKey = isHabit
        ? Task(
            id: 'tmp',
            title: 'tmp',
            createdAt: now,
            kind: TaskKind.habit,
            habitSchedule: _habitSchedule,
          ).periodKeyFor(now)
        : null;

    if (_isEditing) {
      final task = widget.task!;
      final kindChanged = task.kind != _kind;
      controller.update(
        task.copyWith(
          title: title,
          notes: notes,
          focusMinutes: _focusMinutes,
          priority: _priority,
          tag: tag,
          kind: _kind,
          targetAmount: target,
          clearTargetAmount: target == null,
          targetUnit: unit,
          customUnit: customUnit,
          habitSchedule: _habitSchedule,
          weekdays: weekdayList,
          monthDays: monthDays,
          progressAmount: kindChanged ? 0 : task.progressAmount,
          progressPeriodKey: kindChanged
              ? progressPeriodKey
              : task.progressPeriodKey,
          clearProgressPeriod: kindChanged,
          dueDate: isHabit ? null : _dueDate,
          clearDueDate: isHabit || _dueDate == null,
        ),
      );
    } else {
      controller.add(
        Task(
          id: newId('task'),
          title: title,
          notes: notes,
          focusMinutes: _focusMinutes,
          priority: _priority,
          tag: tag,
          kind: _kind,
          targetAmount: target,
          targetUnit: unit,
          customUnit: customUnit,
          habitSchedule: _habitSchedule,
          weekdays: weekdayList,
          monthDays: monthDays,
          progressPeriodKey: progressPeriodKey,
          dueDate: isHabit ? null : _dueDate,
          createdAt: now,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '拔掉这个待办？',
      message: '删除后无法恢复，已经产生的专注记录会保留。',
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
                    _isEditing ? '编辑待办' : '种下一颗新待办',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: '删除待办',
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
            const SizedBox(height: 10),
            const _FieldLabel(title: '要做什么', hint: '先定待办，再定时间'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: '比如：写完项目复盘',
                counterText: '',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            _TypeSelector(value: _kind, onChanged: _changeKind),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: _FieldLabel(title: '单次专注时长')),
                _FocusMinutesPicker(
                  value: _focusMinutes,
                  onChanged: (value) => setState(() => _focusMinutes = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_kind != TaskKind.pomodoro) ...[
              _FieldLabel(
                title: _kind == TaskKind.goal ? '目标总量' : '习惯每个周期的目标',
                hint: _kind == TaskKind.goal ? '完成多少算达成' : '完成多少算打卡',
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(hintText: '例如 4 或 30'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _UnitPicker(
                      value: _targetUnit,
                      onChanged: (unit) => setState(() => _targetUnit = unit),
                    ),
                  ),
                ],
              ),
              if (_targetUnit == TaskUnit.custom) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customUnitController,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    hintText: '自定义单位，如 页、公里、首歌',
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            if (_kind == TaskKind.habit) ...[
              const _FieldLabel(title: '习惯节奏'),
              const SizedBox(height: 8),
              _HabitSchedulePicker(
                value: _habitSchedule,
                onChanged: (value) => setState(() => _habitSchedule = value),
              ),
              if (_habitSchedule == HabitSchedule.weekdays) ...[
                const SizedBox(height: 10),
                _WeekdayPicker(
                  selected: _weekdays,
                  onToggle: (day) => setState(() {
                    if (!_weekdays.remove(day)) _weekdays.add(day);
                  }),
                ),
              ],
              if (_habitSchedule == HabitSchedule.monthDays) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _monthDaysController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    hintText: '每月哪几天？如 1, 5, 15',
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            if (_kind != TaskKind.habit) ...[
              const _FieldLabel(title: '日期'),
              const SizedBox(height: 8),
              _DateChoiceRow(
                dueDate: _dueDate,
                required: _kind == TaskKind.goal,
                onPick: _pickDate,
                onClear: () => setState(() => _dueDate = null),
                onQuick: (days) => setState(
                  () => _dueDate = days == null
                      ? null
                      : addDays(DateTime.now(), days),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const _FieldLabel(title: '优先级'),
            const SizedBox(height: 8),
            _PriorityPicker(
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 20),
            const _FieldLabel(title: '标签', hint: '自己写，不需要选'),
            const SizedBox(height: 8),
            TextField(
              controller: _tagController,
              maxLength: 12,
              decoration: const InputDecoration(
                hintText: '比如：备考、论文、晨间',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
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
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? '保存修改' : '种下这颗待办'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final TaskKind value;
  final ValueChanged<TaskKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final kind in TaskKind.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: kind == TaskKind.habit ? 0 : 8),
              child: GestureDetector(
                onTap: () => onChanged(kind),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: value == kind
                        ? scheme.primary.withValues(
                            alpha: context.isDark ? 0.2 : 0.1,
                          )
                        : surfaces.cardMuted.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: value == kind
                          ? scheme.primary.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        switch (kind) {
                          TaskKind.pomodoro => Icons.timer_outlined,
                          TaskKind.goal => Icons.flag_outlined,
                          TaskKind.habit => Icons.eco_outlined,
                        },
                        size: 18,
                        color: value == kind ? scheme.primary : surfaces.muted,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        kind.shortLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: value == kind
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: value == kind
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
    );
  }
}

class _FocusMinutesPicker extends StatelessWidget {
  const _FocusMinutesPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: surfaces.cardMuted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 5 ? () => onChanged(value - 5) : null,
            icon: const Icon(Icons.remove_rounded, size: 16),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '$value 分',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < 180 ? () => onChanged(value + 5) : null,
            icon: const Icon(Icons.add_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}

class _UnitPicker extends StatelessWidget {
  const _UnitPicker({required this.value, required this.onChanged});

  final TaskUnit value;
  final ValueChanged<TaskUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return PopupMenuButton<TaskUnit>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final unit in TaskUnit.values)
          PopupMenuItem(value: unit, child: Text(unit.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: surfaces.cardMuted.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.label,
                style: TextStyle(fontSize: 13, color: context.onSurface),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: surfaces.faint),
          ],
        ),
      ),
    );
  }
}

class _HabitSchedulePicker extends StatelessWidget {
  const _HabitSchedulePicker({required this.value, required this.onChanged});

  final HabitSchedule value;
  final ValueChanged<HabitSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final schedule in HabitSchedule.values)
          GestureDetector(
            onTap: () => onChanged(schedule),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: value == schedule
                    ? scheme.primary.withValues(alpha: 0.12)
                    : surfaces.cardMuted.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: value == schedule
                      ? scheme.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                schedule.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: value == schedule
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: value == schedule ? scheme.primary : surfaces.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (var day = 1; day <= 7; day += 1)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: day == 7 ? 0 : 5),
              child: GestureDetector(
                onTap: () => onToggle(day),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected.contains(day)
                        ? scheme.primary.withValues(alpha: 0.12)
                        : surfaces.cardMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[day - 1],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected.contains(day)
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: selected.contains(day)
                          ? scheme.primary
                          : surfaces.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateChoiceRow extends StatelessWidget {
  const _DateChoiceRow({
    required this.dueDate,
    required this.required,
    required this.onPick,
    required this.onClear,
    required this.onQuick,
  });

  final DateTime? dueDate;
  final bool required;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ValueChanged<int?> onQuick;

  @override
  Widget build(BuildContext context) {
    final options = <(String, int?, bool)>[
      ('今天', 0, dueDate != null && isToday(dueDate!)),
      (
        '明天',
        1,
        dueDate != null && isSameDay(dueDate!, addDays(DateTime.now(), 1)),
      ),
      (
        '一周后',
        7,
        dueDate != null && isSameDay(dueDate!, addDays(DateTime.now(), 7)),
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!required)
          _DatePill(label: '不设置', selected: dueDate == null, onTap: onClear),
        for (final option in options)
          _DatePill(
            label: option.$1,
            selected: option.$3,
            onTap: () => onQuick(option.$2),
          ),
        _DatePill(
          label: dueDate == null ? '选日期' : '${dueDate!.month}月${dueDate!.day}日',
          selected:
              dueDate != null &&
              !isToday(dueDate!) &&
              !isSameDay(dueDate!, addDays(DateTime.now(), 1)) &&
              !isSameDay(dueDate!, addDays(DateTime.now(), 7)),
          icon: Icons.calendar_today_rounded,
          onTap: onPick,
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: context.isDark ? 0.22 : 0.1)
              : surfaces.cardMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
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
                fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: value == priority
                        ? _color(priority).withValues(alpha: 0.12)
                        : surfaces.cardMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: value == priority
                          ? _color(priority).withValues(alpha: 0.55)
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
                          fontSize: 11.5,
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
