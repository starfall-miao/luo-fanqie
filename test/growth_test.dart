import 'package:flutter_test/flutter_test.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/features/growth/models/growth_item.dart';
import 'package:luo_fanqie_app/features/growth/models/life_area.dart';
import 'package:luo_fanqie_app/features/growth/providers/growth_controller.dart';

void main() {
  final now = DateTime(2026, 11, 8, 9);

  test('习惯每天只能打卡一次并累计连续天数', () {
    final controller = GrowthController(MemoryStorage(), clock: () => now);
    controller.add(
      GrowthItem(
        id: 'habit-1',
        title: '喝水',
        type: GrowthType.habit,
        createdAt: now,
      ),
    );
    expect(controller.todayChecked, 0);
    controller.checkInHabit('habit-1');
    expect(controller.todayChecked, 1);
    expect(controller.habits.single.streak, 1);
    controller.checkInHabit('habit-1');
    expect(controller.habits.single.totalCheckIns, 1);
  });

  test('长期目标进度不会超过目标', () {
    final controller = GrowthController(MemoryStorage(), clock: () => now);
    controller.add(
      GrowthItem(
        id: 'goal-1',
        title: '读完一本书',
        type: GrowthType.learning,
        target: 10,
        createdAt: now,
      ),
    );
    controller.addProgress('goal-1', 20);
    expect(controller.plans.single.progress, 10);
    expect(controller.plans.single.ratio, 1);
  });

  test('人生领域可添加、自动补齐并安全移除', () {
    final controller = GrowthController(MemoryStorage(), clock: () => now);
    expect(controller.areas.map((area) => area.name), contains('学习'));

    controller.ensureArea('番茄ToDo导入');
    expect(controller.areas.map((area) => area.name), contains('番茄ToDo导入'));

    controller.add(
      GrowthItem(
        id: 'item-1',
        title: '整理笔记',
        type: GrowthType.goal,
        area: '番茄ToDo导入',
        createdAt: now,
      ),
    );
    controller.removeArea(
      controller.areas.firstWhere((area) => area.name == '番茄ToDo导入').id,
    );
    expect(controller.items.single.area, '未分类');
    expect(controller.areas.length, greaterThan(1));
    expect(controller.areas.first, isA<LifeArea>());
  });
}
