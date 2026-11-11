import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../providers/sync_controller.dart';

/// 打开 GitHub Gist 同步配置。
Future<void> showSyncSettings(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (_) => const _SyncSettingsSheet(),
  );
}

class _SyncSettingsSheet extends StatefulWidget {
  const _SyncSettingsSheet();

  @override
  State<_SyncSettingsSheet> createState() => _SyncSettingsSheetState();
}

class _SyncSettingsSheetState extends State<_SyncSettingsSheet> {
  late final TextEditingController _tokenController;
  late final TextEditingController _gistController;
  late bool _autoSync;
  late bool _tokenVisible;
  String? _error;

  SyncController get _sync => context.read<SyncController>();

  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncController>();
    _tokenController = TextEditingController(text: sync.token);
    _gistController = TextEditingController(text: sync.gistId ?? '');
    _autoSync = sync.autoSync;
    _tokenVisible = sync.token.isEmpty;
    _error = sync.lastError;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _gistController.dispose();
    super.dispose();
  }

  Future<void> _saveAndSync() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = '请填写 GitHub Token');
      return;
    }
    _sync.configure(
      token: token,
      gistId: _gistController.text.trim(),
      autoSync: _autoSync,
    );
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await _sync.syncNow();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = _sync.lastError ?? '同步失败');
    } else {
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('同步完成，任务和专注记录已合并')));
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '断开同步？',
      message: '只会清除本机的同步配置，不会删除云端的 Gist，也不会改动本地任务。',
      confirmText: '断开',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _sync.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final sync = context.watch<SyncController>();
    final configured = _tokenController.text.trim().isNotEmpty;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 180),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    color: scheme.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '跨设备同步',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '用 GitHub Gist 交换任务与专注记录',
                        style: TextStyle(fontSize: 11, color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                if (sync.isConfigured)
                  TextButton(onPressed: _disconnect, child: const Text('断开'))
                else
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaces.cardMuted.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: surfaces.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '首次同步会创建一个私密 Gist。其他设备登录同一 GitHub 账号、填入同一个 Token 即可自动找到它；Token 只保存在本机，不会上传到落·番茄的仓库。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        color: surfaces.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SyncFieldLabel('GitHub Token'),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              obscureText: !_tokenVisible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'ghp_… 或 github_pat_…',
                suffixIcon: IconButton(
                  tooltip: _tokenVisible ? '隐藏 Token' : '显示 Token',
                  icon: Icon(
                    _tokenVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  onPressed: () =>
                      setState(() => _tokenVisible = !_tokenVisible),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              '建议创建仅勾选 “Gists” 读写权限的 fine-grained token。GitHub → Settings → Developer settings → Personal access tokens。',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.55,
                color: surfaces.faint,
              ),
            ),
            const SizedBox(height: 18),
            const _SyncFieldLabel('Gist ID（可选）'),
            const SizedBox(height: 8),
            TextField(
              controller: _gistController,
              autocorrect: false,
              decoration: const InputDecoration(hintText: '留空会自动查找或创建'),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(
                color: surfaces.cardMuted.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自动同步',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '任务或专注记录变化后自动同步，回到前台时也会拉取一次。',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: surfaces.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoSync,
                    onChanged: (value) => setState(() => _autoSync = value),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.error,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (sync.lastSyncAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '上次同步：${relativeDayLabel(sync.lastSyncAt!)} ${clockLabel(sync.lastSyncAt!)}',
                style: TextStyle(fontSize: 10.5, color: surfaces.faint),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: sync.isSyncing || !configured ? null : _saveAndSync,
                child: Text(sync.isSyncing ? '同步中…' : '保存并同步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncFieldLabel extends StatelessWidget {
  const _SyncFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: context.surfaces.muted,
      ),
    );
  }
}
