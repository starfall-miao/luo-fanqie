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

Future<void> _openLegacyFocus(WidgetTester tester) async {
  await tester.tap(find.text('计时').first);
  await tester.pumpAndSettle();
}

Future<void> _openLegacyTasks(WidgetTester tester) async {
  await tester.tap(find.text('待办').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('今日工作台展示集成、成长与旧模块入口', (tester) async {
    await _pumpApp(tester);

    expect(find.text('今天，先做最重要的一件事'), findsOneWidget);
    expect(find.text('番茄 ToDo 联动'), findsOneWidget);
    expect(find.text('今日成长'), findsOneWidget);
    expect(find.text('计时'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(find.text('今日'), findsWidgets);
    expect(find.text('成长'), findsWidgets);
    expect(find.text('数据'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('从今日进入旧专注并开始暂停', (tester) async {
    await _pumpApp(tester);
    await _openLegacyFocus(tester);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('从今日进入待办并新建', (tester) async {
    await _pumpApp(tester);
    await _openLegacyTasks(tester);
    expect(find.text('待办清单'), findsOneWidget);

    await tester.tap(find.byTooltip('新建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '写测试，也是一种专注');
    await tester.pump();
    await tester.ensureVisible(find.text('种下这颗待办'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('种下这颗待办'));
    await tester.pumpAndSettle();

    expect(find.text('写测试，也是一种专注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('成长可以添加并打卡习惯', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.trending_up_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('长期成长'), findsOneWidget);

    await tester.tap(find.byTooltip('添加成长项目'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '喝水');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('喝水'), findsOneWidget);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    expect(find.textContaining('连续 1 天'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('守护页展示番茄ToDo与权限入口', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    expect(find.text('番茄 ToDo 联动'), findsOneWidget);
    expect(find.textContaining('com.plan.kot32.tomatotime'), findsWidgets);
    expect(find.text('系统权限'), findsOneWidget);
    expect(find.text('锁机计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数据和我的入口可用', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('专注统计'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('偏好设置'), findsOneWidget);
    await tester.ensureVisible(find.text('专注增强'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('专注增强'));
    await tester.pumpAndSettle();
    expect(find.text('专注时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏侧边栏可以进入完整待办与数据', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(1280, 800),
      devicePixelRatio: 2,
    );
    expect(find.text('今天，先做最重要的一件事'), findsOneWidget);

    await tester.tap(find.text('待办').first);
    await tester.pumpAndSettle();
    expect(find.text('待办清单'), findsOneWidget);
    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('数据').first);
    await tester.pumpAndSettle();
    expect(find.text('专注统计'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('锁机入口打开时长选择', (tester) async {
    await _pumpApp(tester);
    await _openLegacyFocus(tester);
    await tester.tap(find.text('锁机专注'));
    await tester.pumpAndSettle();
    expect(find.text('落落要把门关上啦'), findsOneWidget);
    await tester.tap(find.text('今天先不锁'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('学霸模式进入沉浸页', (tester) async {
    await _pumpApp(
      tester,
      storage: MemoryStorage({
        'luo_fanqie.settings.v1': const AppSettings(strictMode: true).encode(),
      }),
    );
    await _openLegacyFocus(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.text('暂停 3 分钟'), findsOneWidget);
    expect(find.text('结束守护'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽小屏主要页面不溢出', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(320, 640),
      devicePixelRatio: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.trending_up_rounded).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('900 宽横屏侧边栏不溢出', (tester) async {
    await _pumpApp(
      tester,
      logicalSize: const Size(900, 600),
      devicePixelRatio: 2,
    );
    expect(find.text('今天，先做最重要的一件事'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('放大字体后主要页面仍不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.trending_up_rounded).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计支持日周月年切换', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('周统计表'), findsOneWidget);
    await tester.tap(find.text('日').first);
    await tester.pumpAndSettle();
    expect(find.text('日统计表'), findsOneWidget);
    await tester.tap(find.text('年').first);
    await tester.pumpAndSettle();
    expect(find.text('年统计表'), findsOneWidget);
    expect(find.text('打断原因'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
