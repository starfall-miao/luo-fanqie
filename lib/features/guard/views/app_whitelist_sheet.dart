import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/immersive/immersive_mode_service.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_controller.dart';
import '../services/app_whitelist_service.dart';

Future<void> showAppWhitelistPicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (_) => const _AppWhitelistSheet(),
  );
}

Future<void> showWhitelistLauncher(BuildContext context) async {
  final settings = context.read<SettingsController>();
  final selected = settings.settings.whitelistPackages;
  if (selected.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('还没有设置白名单应用')));
    return;
  }
  const service = AppWhitelistService();
  final apps = await service.listApps();
  if (!context.mounted) return;
  final allowed = apps
      .where((app) => selected.contains(app.packageName))
      .toList(growable: false);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (sheetContext) => _WhitelistLauncherSheet(apps: allowed),
  );
}

class _AppWhitelistSheet extends StatefulWidget {
  const _AppWhitelistSheet();

  @override
  State<_AppWhitelistSheet> createState() => _AppWhitelistSheetState();
}

class _AppWhitelistSheetState extends State<_AppWhitelistSheet> {
  static const _service = AppWhitelistService();

  late final Set<String> _selected;
  late Future<List<InstalledApp>> _appsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = context
        .read<SettingsController>()
        .settings
        .whitelistPackages
        .toSet();
    _appsFuture = _service.listApps();
  }

  void _save() {
    context.read<SettingsController>().setWhitelistPackages(
      _selected.toList(growable: false),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _selected.isEmpty
                ? '白名单已清空：严格专注时不允许其他 App'
                : '已保存 ${_selected.length} 个白名单应用',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '白名单应用',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '只选真正需要的 App（查资料、词典等）。不选择时，严格专注不允许打开其他 App。',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: surfaces.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(() => _selected.clear()),
                    child: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  hintText: '搜索应用名称',
                  prefixIcon: Icon(Icons.search_rounded, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<InstalledApp>>(
                  future: _appsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snapshot.data ?? const <InstalledApp>[];
                    if (all.isEmpty) {
                      return Center(
                        child: Text(
                          '没有读取到可启动应用。\n请确认系统权限或改用 WebDAV 版？',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: surfaces.muted,
                          ),
                        ),
                      );
                    }
                    final visible = _query.isEmpty
                        ? all
                        : all
                              .where(
                                (app) =>
                                    app.label.toLowerCase().contains(
                                      _query.toLowerCase(),
                                    ) ||
                                    app.packageName.toLowerCase().contains(
                                      _query.toLowerCase(),
                                    ),
                              )
                              .toList(growable: false);
                    if (visible.isEmpty) {
                      return Center(
                        child: Text(
                          '没有匹配的应用',
                          style: TextStyle(color: surfaces.muted),
                        ),
                      );
                    }
                    final suggestions = _query.isEmpty
                        ? all
                              .where(
                                (app) =>
                                    app.isEducation &&
                                    !_selected.contains(app.packageName),
                              )
                              .take(6)
                              .toList(growable: false)
                        : const <InstalledApp>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (suggestions.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                            decoration: BoxDecoration(
                              color: AppPalette.sage.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '学习应用建议',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.sage,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '按教育分类与关键词识别，已排除手机厂商自带应用。',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: surfaces.faint,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final app in suggestions)
                                      ActionChip(
                                        label: Text(app.label),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(
                                            () =>
                                                _selected.add(app.packageName),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Expanded(
                          child: ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final app = visible[index];
                              final checked = _selected.contains(
                                app.packageName,
                              );
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(app.packageName);
                                    } else {
                                      _selected.remove(app.packageName);
                                    }
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  app.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  app.packageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: surfaces.faint,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    _selected.isEmpty
                        ? '保存（不允许其他 App）'
                        : '保存 ${_selected.length} 个应用',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhitelistLauncherSheet extends StatelessWidget {
  const _WhitelistLauncherSheet({required this.apps});

  final List<InstalledApp> apps;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Padding(
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
          Text('打开白名单应用', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '只允许这些应用在专注期间使用。',
            style: TextStyle(fontSize: 11.5, color: surfaces.muted),
          ),
          const SizedBox(height: 12),
          if (apps.isEmpty)
            Text('白名单里的应用当前不可用。', style: TextStyle(color: surfaces.faint))
          else
            for (final app in apps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.apps_rounded, color: context.primary),
                title: Text(app.label),
                subtitle: Text(
                  app.packageName,
                  style: TextStyle(fontSize: 10, color: surfaces.faint),
                ),
                onTap: () async {
                  // 白名单应用不应该被 screen pinning 拦在门外。
                  await const ImmersiveModeService().stopLockTask();
                  final ok = await const AppWhitelistService().launchApp(
                    app.packageName,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    if (!ok) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('启动失败，可能被锁定任务阻止')),
                        );
                    }
                  }
                },
              ),
        ],
      ),
    );
  }
}
