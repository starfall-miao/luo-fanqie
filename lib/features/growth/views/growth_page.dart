import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../models/growth_item.dart';
import '../providers/growth_controller.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GrowthController>();
    final habits = controller.habits;
    final plans = controller.plans;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: '成长',
                  title: '长期成长',
                  subtitle: '番茄 ToDo 管一颗番茄，这里管一整个阶段的自己。',
                  trailing: CircleIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '添加成长项目',
                    size: 44,
                    filled: true,
                    onPressed: () => _addGrowth(context),
                  ),
                ),
                const SizedBox(height: 16),
                _Overview(controller: controller),
                const SizedBox(height: 16),
                _Section(
                  title: '全天习惯',
                  subtitle: '不绑番茄，也能每天打卡',
                  count: habits.length,
                  empty: '还没有全天习惯。从喝水、拉伸、阅读十分钟开始。',
                  children: [
                    for (final habit in habits)
                      _HabitRow(
                        item: habit,
                        onCheck: () => controller.checkInHabit(habit.id),
                        onRemove: () => controller.remove(habit.id),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _Section(
                  title: '目标与学习',
                  subtitle: '阶段目标与学习计划',
                  count: plans.length,
                  empty: '还没有长期目标或学习计划。',
                  children: [
                    for (final plan in plans)
                      _PlanRow(
                        item: plan,
                        onProgress: () => controller.addProgress(plan.id, 1),
                        onRemove: () => controller.remove(plan.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addGrowth(BuildContext context) async {
    final controller = context.read<GrowthController>();
    final title = TextEditingController();
    final area = TextEditingController(text: '成长');
    final target = TextEditingController(text: '30');
    var type = GrowthType.habit;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('添加成长项目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<GrowthType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: [
                    for (final item in GrowthType.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setModalState(() => type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(hintText: '名称'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: area,
                  decoration: const InputDecoration(hintText: '人生领域'),
                ),
                if (type != GrowthType.habit) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '目标量'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (result != true || title.text.trim().isEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        title.dispose();
        area.dispose();
        target.dispose();
      });
      return;
    }
    final amount = int.tryParse(target.text.trim()) ?? 30;
    controller.add(
      GrowthItem(
        id: 'growth-${DateTime.now().microsecondsSinceEpoch}',
        title: title.text.trim(),
        type: type,
        area: area.text.trim().isEmpty ? '成长' : area.text.trim(),
        target: amount,
        createdAt: DateTime.now(),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      title.dispose();
      area.dispose();
      target.dispose();
    });
    HapticFeedback.mediumImpact();
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.controller});

  final GrowthController controller;

  @override
  Widget build(BuildContext context) {
    final habits = controller.habits;
    final checked = controller.todayChecked;
    final ratio = habits.isEmpty ? 0.0 : checked / habits.length;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 5,
                  backgroundColor: context.surfaces.track,
                ),
                Text(
                  '$checked/${habits.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日习惯', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  habits.isEmpty
                      ? '先添加一个全天习惯'
                      : '$checked 个已完成 · ${habits.length - checked} 个待完成',
                  style: TextStyle(fontSize: 12, color: context.surfaces.muted),
                ),
              ],
            ),
          ),
          InfoPill(
            icon: Icons.trending_up_rounded,
            label: '${controller.plans.length} 个长期计划',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.empty,
    required this.children,
  });

  final String title;
  final String subtitle;
  final int count;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: title,
            subtitle: subtitle,
            trailing: Text(
              '$count 项',
              style: TextStyle(fontSize: 11, color: context.surfaces.faint),
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                empty,
                style: TextStyle(fontSize: 12, color: context.surfaces.muted),
              ),
            )
          else
            for (final child in children) child,
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.item,
    required this.onCheck,
    required this.onRemove,
  });

  final GrowthItem item;
  final VoidCallback onCheck;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final checked = item.checkedToday;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onCheck,
      leading: Icon(
        checked
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: checked ? AppPalette.sage : context.surfaces.faint,
      ),
      title: Text(item.title),
      subtitle: Text(
        '${item.area} · 连续 ${item.streak} 天',
        style: TextStyle(fontSize: 10.5, color: context.surfaces.faint),
      ),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded, size: 16),
        tooltip: '移除',
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.item,
    required this.onProgress,
    required this.onRemove,
  });

  final GrowthItem item;
  final VoidCallback onProgress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title, style: const TextStyle(fontSize: 13.5)),
              ),
              Text(
                '${item.progress.toStringAsFixed(0)}/${item.target}',
                style: TextStyle(fontSize: 11, color: context.surfaces.muted),
              ),
              IconButton(
                onPressed: onProgress,
                tooltip: '增加进度',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 16),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: '移除',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SoftProgressBar(
            value: item.ratio,
            height: 5,
            color: item.type == GrowthType.learning
                ? AppPalette.sky
                : AppPalette.apricot,
          ),
        ],
      ),
    );
  }
}
