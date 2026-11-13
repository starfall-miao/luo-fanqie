import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/notifications/timer_notification_service.dart';
import 'core/storage/key_value_storage.dart';
import 'features/settings/providers/settings_controller.dart';
import 'features/soundscape/soundscape_controller.dart';
import 'features/stats/providers/stats_controller.dart';
import 'features/sync/providers/sync_controller.dart';
import 'features/tasks/providers/task_controller.dart';
import 'features/timer/providers/pomodoro_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await SharedPreferencesStorage.open();
  runApp(LuoFanqieBootstrap(storage: storage));
}

/// 组装全部控制器。放在 StatefulWidget 里，确保退出时正确释放计时器。
class LuoFanqieBootstrap extends StatefulWidget {
  const LuoFanqieBootstrap({super.key, required this.storage, this.clock});

  final KeyValueStorage storage;
  final DateTime Function()? clock;

  @override
  State<LuoFanqieBootstrap> createState() => _LuoFanqieBootstrapState();
}

class _LuoFanqieBootstrapState extends State<LuoFanqieBootstrap> {
  late final SettingsController _settings;
  late final TaskController _tasks;
  late final StatsController _stats;
  late final PomodoroController _timer;
  late final SyncController _sync;
  late final SoundscapeController _soundscape;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(widget.storage);
    _tasks = TaskController(widget.storage, clock: widget.clock);
    _stats = StatsController(widget.storage, clock: widget.clock);
    _timer = PomodoroController(
      tasks: _tasks,
      stats: _stats,
      settings: _settings,
      storage: widget.storage,
      notifications: const AndroidTimerNotificationService(),
      clock: widget.clock,
    );
    _sync = SyncController(
      tasks: _tasks,
      stats: _stats,
      storage: widget.storage,
      clock: widget.clock,
    );
    _soundscape = SoundscapeController();
  }

  @override
  void dispose() {
    _soundscape.dispose();
    _sync.dispose();
    _timer.dispose();
    _settings.dispose();
    _tasks.dispose();
    _stats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settings),
        ChangeNotifierProvider.value(value: _tasks),
        ChangeNotifierProvider.value(value: _stats),
        ChangeNotifierProvider.value(value: _timer),
        ChangeNotifierProvider.value(value: _sync),
        ChangeNotifierProvider.value(value: _soundscape),
      ],
      child: const LuoFanqieApp(),
    );
  }
}
