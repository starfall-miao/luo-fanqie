import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/main.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  Size logicalSize = const Size(390, 844),
  double devicePixelRatio = 3.0,
}) async {
  tester.view.physicalSize = Size(
    logicalSize.width * devicePixelRatio,
    logicalSize.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    LuoFanqieBootstrap(
      storage: MemoryStorage(),
      clock: () => DateTime(2026, 11, 8, 9, 30),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('首页展示品牌、计时盘与底部导航', (tester) async {
    await _pumpApp(tester);

    expect(find.text('落·番茄'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('准备专注'), findsOneWidget);
    expect(find.text('选择要专注的任务'), findsOneWidget);
    expect(find.text('专注'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('统计'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以开始与暂停计时', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(find.text('正在专注，点按暂停'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('已暂停，继续加油'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('可以新建任务并浏览统计与设置页', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    expect(find.text('一棵一棵，慢慢长大'), findsOneWidget);

    await tester.tap(find.byTooltip('新建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '写测试，也是一种专注');
    await tester.pump();
    await tester.tap(find.text('种下这颗任务'));
    await tester.pumpAndSettle();

    expect(find.text('写测试，也是一种专注'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('时间留下的形状'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('好好生活，慢慢专注'), findsOneWidget);

    await tester.ensureVisible(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    expect(tester.takeException(), isNull);
  });

  testWidgets('小屏手机各页面布局稳定', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(360, 740),
      devicePixelRatio: 2,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏使用侧边导航且不溢出', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(1280, 800),
      devicePixelRatio: 2,
    );
    expect(find.text('把时间种成番茄'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    expect(find.text('一棵一棵，慢慢长大'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('时间留下的形状'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('好好生活，慢慢专注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以从待办中选择专注任务', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('选择要专注的任务'));
    await tester.pumpAndSettle();
    expect(find.text('这次，专注于什么？'), findsOneWidget);

    await tester.tap(find.text('写下今天最重要的一件事'));
    await tester.pumpAndSettle();
    expect(find.text('写下今天最重要的一件事'), findsWidgets);
    expect(find.text('选择要专注的任务'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('修改专注时长会同步到计时器', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('专注时长'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('专注时长'));
    await tester.pumpAndSettle();
    expect(find.text('让一颗番茄刚好装下一段注意力。'), findsOneWidget);

    await tester.tap(find.text('45 分钟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('45 分钟'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    expect(find.text('45:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
