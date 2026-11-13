import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/features/focus/views/session_page.dart';
import 'package:luo_fanqie_app/features/settings/models/app_settings.dart';
import 'package:luo_fanqie_app/main.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  Size logicalSize = const Size(390, 844),
  double devicePixelRatio = 3.0,
  MemoryStorage? storage,
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
      storage: storage ?? MemoryStorage(),
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
    await tester.pumpAndSettle();
    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(SessionPage), findsOneWidget);
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
    await tester.ensureVisible(find.text('种下这颗待办'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('种下这颗待办'));
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

  testWidgets('宽屏使用无标签栏的卡片仪表盘', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(1280, 800),
      devicePixelRatio: 2,
    );
    expect(find.textContaining('把时间种成番茄'), findsWidgets);
    expect(find.text('快速开始一颗番茄'), findsOneWidget);
    expect(find.text('今日专注'), findsWidgets);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('好好生活，慢慢专注'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('快速开始一颗番茄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以从待办中选择专注任务', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('选择要专注的任务'));
    await tester.pumpAndSettle();
    expect(find.text('这次，专注于什么？'), findsOneWidget);

    await tester.tap(find.text('完成落·番茄的首页设计'));
    await tester.pumpAndSettle();
    expect(find.text('完成落·番茄的首页设计'), findsWidgets);
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

  testWidgets('任务卡片可以一键开始专注', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始').first);
    await tester.pumpAndSettle();

    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('可以打开跨设备同步设置', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('文件服务器同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件服务器同步'));
    await tester.pumpAndSettle();

    expect(find.text('跨设备同步'), findsWidgets);
    expect(find.text('服务器类型'), findsOneWidget);
    expect(find.text('保存并同步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板横屏使用卡片仪表盘且不溢出', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(1024, 768),
      devicePixelRatio: 2,
    );
    expect(find.text('快速开始一颗番茄'), findsOneWidget);
    expect(find.text('待办'), findsWidgets);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('好好生活，慢慢专注'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('快速开始一颗番茄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学霸模式进入沉浸页并隐藏暂停与最小化', (tester) async {
    await _pumpApp(
      tester,
      storage: MemoryStorage({
        'luo_fanqie.settings.v1': const AppSettings(strictMode: true).encode(),
      }),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.text('学霸模式'), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byTooltip('最小化'), findsNothing);
    expect(find.text('结束锁机'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('任务编辑器可以在三种类型间切换', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();
    expect(find.text('目标总量'), findsOneWidget);

    await tester.tap(find.text('习惯').last);
    await tester.pumpAndSettle();
    expect(find.text('习惯节奏'), findsOneWidget);
    expect(find.text('每天'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('安全与权限页可查看且不触发额外授权', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('安全与权限'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安全与权限'));
    await tester.pumpAndSettle();

    expect(find.text('把数据，留在自己手里'), findsOneWidget);
    expect(find.text('权限按需申请'), findsOneWidget);
    expect(find.text('不会申请的权限'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('好好生活，慢慢专注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
