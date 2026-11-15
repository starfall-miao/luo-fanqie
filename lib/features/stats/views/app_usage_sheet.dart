import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/soft_card.dart';
import '../services/app_usage_service.dart';

Future<void> showAppUsageDetails(
  BuildContext context, {
  required DateTime start,
  required DateTime end,
  required String label,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (_) => _AppUsageDetailsSheet(start: start, end: end, label: label),
  );
}

class _AppUsageDetailsSheet extends StatefulWidget {
  const _AppUsageDetailsSheet({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  @override
  State<_AppUsageDetailsSheet> createState() => _AppUsageDetailsSheetState();
}

class _AppUsageDetailsSheetState extends State<_AppUsageDetailsSheet> {
  static const _service = AppUsageService();
  late Future<List<AppUsageEntry>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.query(start: widget.start, end: widget.end);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return FractionallySizedBox(
      heightFactor: 0.86,
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
            Text(
              '应用使用 · ${widget.label}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '统计你在这段时间打开了哪些 App。数据只在本机汇总。',
              style: TextStyle(fontSize: 11.5, color: surfaces.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: '搜索应用',
                prefixIcon: Icon(Icons.search_rounded, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<AppUsageEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Text(
                        '正在读取…',
                        style: TextStyle(color: surfaces.faint),
                      ),
                    );
                  }
                  final all = snapshot.data ?? const <AppUsageEntry>[];
                  final visible = _query.isEmpty
                      ? all
                      : all
                            .where(
                              (entry) =>
                                  entry.label.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  entry.packageName.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                            )
                            .toList(growable: false);
                  if (visible.isEmpty) {
                    return Center(
                      child: Text(
                        '没有可用的应用使用记录。',
                        style: TextStyle(color: surfaces.faint),
                      ),
                    );
                  }
                  final maxMinutes = visible.first.minutes;
                  return ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: surfaces.border.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: surfaces.faint),
                        ),
                        trailing: Text(
                          '${entry.minutes} 分钟',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.onSurface,
                          ),
                        ),
                        onTap: () => _showSingle(context, entry, maxMinutes),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSingle(BuildContext context, AppUsageEntry entry, int maxMinutes) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.label,
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              entry.packageName,
              style: TextStyle(
                fontSize: 11,
                color: sheetContext.surfaces.faint,
              ),
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.minutes} 分钟',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: sheetContext.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '占本周期统计最高的 ${((entry.minutes / maxMinutes) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: sheetContext.surfaces.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
