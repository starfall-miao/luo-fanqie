import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luo_fanqie_app/core/storage/key_value_storage.dart';
import 'package:luo_fanqie_app/core/theme/app_theme.dart';
import 'package:luo_fanqie_app/core/utils/date_utils.dart';
import 'package:luo_fanqie_app/features/home/views/home_shell.dart';
import 'package:luo_fanqie_app/features/settings/models/app_settings.dart';
import 'package:luo_fanqie_app/features/stats/models/focus_session.dart';
import 'package:luo_fanqie_app/features/tasks/models/task.dart';
import 'package:luo_fanqie_app/main.dart';

/// 运行方式：
/// flutter test test/screenshots_test.dart --update-goldens \
///   --dart-define=RUN_GOLDENS=true
const _runGoldens = bool.fromEnvironment('RUN_GOLDENS');

void main() {
  setUpAll(() async {
    if (!_runGoldens) return;
    // 测试渲染器默认使用 Ahem 字体，这里指定一个真实中文字体，
    // 让截图与真机上的中文排版接近。
    AppTheme.debugFontFamily = 'LuoScreenshot';
    AppTheme.debugFontFallback = 'LuoScreenshotLatin';
    await _loadFonts();
  });

  testWidgets('生成主要页面截图', (tester) async {
    debugDisableShadows = false;
    try {
      await _prepare(tester);
      await _pumpApp(tester, _seedStorage());

      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/01-focus-light.png'),
      );

      await tester.tap(find.byIcon(Icons.checklist_rounded));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/02-tasks.png'),
      );

      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/03-stats.png'),
      );

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/04-settings.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_runGoldens);

  testWidgets('生成深色首页截图', (tester) async {
    debugDisableShadows = false;
    try {
      await _prepare(tester);
      await _pumpApp(tester, _seedStorage(themeMode: AppThemeMode.dark));
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/05-focus-dark.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_runGoldens);

  testWidgets('生成统计长图', (tester) async {
    debugDisableShadows = false;
    try {
      await _prepare(tester, logicalSize: const Size(390, 1460));
      await _pumpApp(tester, _seedStorage());
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/06-stats-full.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_runGoldens);

  testWidgets('生成宽屏截图', (tester) async {
    debugDisableShadows = false;
    try {
      await _prepare(tester, logicalSize: const Size(1280, 800));
      await _pumpApp(tester, _seedStorage());
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/08-wide-focus.png'),
      );
      await tester.tap(find.byIcon(Icons.checklist_rounded));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/09-wide-tasks.png'),
      );
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/10-wide-stats.png'),
      );
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/11-wide-settings.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_runGoldens);

  testWidgets('生成任务编辑截图', (tester) async {
    debugDisableShadows = false;
    try {
      await _prepare(tester);
      await _pumpApp(tester, _seedStorage());
      await tester.tap(find.byIcon(Icons.checklist_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建任务'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/07-task-editor.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_runGoldens);
}

Future<void> _prepare(
  WidgetTester tester, {
  Size logicalSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = Size(
    logicalSize.width * 2,
    logicalSize.height * 2,
  );
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpApp(WidgetTester tester, MemoryStorage storage) async {
  await tester.pumpWidget(
    LuoFanqieBootstrap(storage: storage, clock: () => DateTime.now()),
  );
  await tester.pumpAndSettle();
}

MemoryStorage _seedStorage({AppThemeMode themeMode = AppThemeMode.light}) {
  final now = DateTime.now();
  final today = startOfDay(now);
  final tasks = <Task>[
    Task(
      id: 't1',
      title: '完成落·番茄的首页设计',
      notes: '把计时器和任务流串起来',
      estimatedPomodoros: 4,
      completedPomodoros: 2,
      priority: TaskPriority.high,
      tag: '工作',
      dueDate: today,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    Task(
      id: 't2',
      title: '读完《深度工作》第三章',
      estimatedPomodoros: 2,
      priority: TaskPriority.medium,
      tag: '阅读',
      dueDate: addDays(today, 1),
      createdAt: now.subtract(const Duration(hours: 4)),
    ),
    Task(
      id: 't3',
      title: '给阳台的番茄浇水',
      estimatedPomodoros: 1,
      priority: TaskPriority.low,
      tag: '生活',
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    Task(
      id: 't4',
      title: '整理今天的会议笔记',
      estimatedPomodoros: 1,
      completedPomodoros: 1,
      priority: TaskPriority.medium,
      tag: '工作',
      done: true,
      createdAt: now.subtract(const Duration(days: 1)),
      completedAt: now.subtract(const Duration(hours: 6)),
    ),
  ];

  final counts = <int, int>{
    0: 3,
    1: 2,
    2: 1,
    3: 0,
    4: 3,
    5: 2,
    6: 1,
    7: 2,
    8: 0,
    9: 1,
    10: 3,
    11: 2,
    12: 0,
    13: 1,
    14: 2,
    15: 3,
    16: 1,
    17: 0,
    18: 2,
    19: 1,
    20: 2,
    21: 0,
    22: 1,
    23: 2,
    24: 3,
    26: 1,
    27: 2,
    29: 1,
    31: 2,
    33: 1,
    36: 2,
    39: 1,
    42: 2,
    46: 1,
    51: 2,
    56: 1,
  };
  final titles = ['完成落·番茄的首页设计', '读完《深度工作》第三章', '自由专注'];
  final sessions = <FocusSession>[];
  var id = 0;
  for (final entry in counts.entries) {
    for (var i = 0; i < entry.value; i += 1) {
      final date = addDays(today, -entry.key);
      final endedAt = DateTime(date.year, date.month, date.day, 10 + i * 2);
      sessions.add(
        FocusSession(
          id: 'seed-${id++}',
          taskId: i == 0 ? 't1' : null,
          taskTitle: titles[(entry.key + i) % titles.length],
          startedAt: endedAt.subtract(const Duration(minutes: 25)),
          endedAt: endedAt,
          minutes: 25,
        ),
      );
    }
  }

  final settings = AppSettings(themeMode: themeMode);
  final timer = <String, dynamic>{
    'version': 1,
    'phase': 'focus',
    'status': 'idle',
    'totalMillis': 25 * 60 * 1000,
    'remainingMillis': 25 * 60 * 1000,
    'endAt': null,
    'phaseStartedAt': null,
    'completedInCycle': 1,
    'selectedTaskId': 't1',
  };

  return MemoryStorage({
    'luo_fanqie.settings.v1': settings.encode(),
    'luo_fanqie.tasks.v1': jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    ),
    'luo_fanqie.sessions.v1': jsonEncode(
      sessions.map((session) => session.toJson()).toList(),
    ),
    'luo_fanqie.timer.v1': jsonEncode(timer),
  });
}

Future<void> _loadFonts() async {
  final home = Platform.environment['HOME'] ?? '';
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '$home/flutter_sdk';
  final cjk = File('/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf');
  final iconFont = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (cjk.existsSync()) {
    await _loadFont('LuoScreenshot', await cjk.readAsBytes());
  }
  final latin = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  if (latin.existsSync()) {
    await _loadFont('LuoScreenshotLatin', await latin.readAsBytes());
  }
  if (iconFont.existsSync()) {
    await _loadFont('MaterialIcons', await iconFont.readAsBytes());
  }
}

Future<void> _loadFont(String family, Uint8List bytes) async {
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}
