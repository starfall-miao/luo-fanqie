import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/common.dart';
import '../models/sync_config.dart';
import '../providers/sync_controller.dart';

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
  late final TextEditingController _serverController;
  late final TextEditingController _portController;
  late final TextEditingController _remoteController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late SyncServerType _type;
  late bool _autoSync;
  late bool _useTls;
  bool _passwordVisible = false;
  bool _busy = false;
  String? _error;

  SyncController get _sync => context.read<SyncController>();

  List<SyncServerType> get _types => SyncServerType.values
      .where((type) => type != SyncServerType.ftp || !kIsWeb)
      .toList();

  @override
  void initState() {
    super.initState();
    final config = context.read<SyncController>().config;
    _type = config?.type ?? SyncServerType.webdav;
    if (kIsWeb && _type == SyncServerType.ftp) _type = SyncServerType.webdav;
    _serverController = TextEditingController(text: config?.serverUrl ?? '');
    _portController = TextEditingController(text: '${config?.port ?? 21}');
    _remoteController = TextEditingController(text: config?.remotePath ?? '');
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(text: config?.password ?? '');
    _autoSync = config?.autoSync ?? false;
    _useTls = config?.useTls ?? false;
    _error = context.read<SyncController>().lastError;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _remoteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SyncConfig _buildConfig() {
    return SyncConfig(
      type: _type,
      serverUrl: _serverController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 21,
      remotePath: _remoteController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      useTls: _useTls,
      autoSync: _autoSync,
    );
  }

  bool _validate(SyncConfig config) {
    if (config.serverUrl.isEmpty) {
      setState(
        () => _error = _type == SyncServerType.ftp
            ? '请填写 FTP 服务器地址'
            : '请填写 WebDAV / Alist 地址',
      );
      return false;
    }
    if (config.type.isHttp) {
      final uri = Uri.tryParse(config.serverUrl);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        setState(() => _error = '地址需要以 http:// 或 https:// 开头');
        return false;
      }
    }
    if (config.port < 1 || config.port > 65535) {
      setState(() => _error = '端口需要在 1–65535 之间');
      return false;
    }
    return true;
  }

  Future<void> _test() async {
    final config = _buildConfig();
    if (!_validate(config)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _sync.testConnection(config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : _sync.lastError;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(ok ? '服务器连接成功' : (_sync.lastError ?? '连接失败'))),
      );
  }

  Future<void> _save() async {
    final config = _buildConfig();
    if (!_validate(config)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _sync.configure(config);
    final ok = await _sync.syncNow();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : _sync.lastError;
    });
    if (!ok) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('同步完成，数据已写入你的文件服务器')));
  }

  Future<void> _disconnect() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '断开文件服务器？',
      message: '只清除本机的同步配置，不会删除服务器上的同步文件，也不会影响本地数据。',
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
    final isFtp = _type == SyncServerType.ftp;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    Icons.dns_rounded,
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
                        '文件服务器同步',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '只连接你自己填写并拥有的服务器',
                        style: TextStyle(fontSize: 11, color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                if (sync.isConfigured)
                  TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: const Text('断开'),
                  )
                else
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaces.cardMuted.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 17, color: surfaces.muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '落·番茄不接入任何第三方云盘，也不会上传数据到我们的服务器。同步只会在你主动点击，或开启自动同步后，访问下面这个地址。建议优先使用 HTTPS WebDAV；FTP 是明文协议，凭据与数据可被网络中间人读取。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.65,
                        color: surfaces.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('服务器类型'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _types)
                  _TypePill(
                    type: type,
                    selected: _type == type,
                    onTap: () => setState(() {
                      _type = type;
                      if (type == SyncServerType.ftp &&
                          _portController.text == '21') {
                        _portController.text = '21';
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _type.hint,
              style: TextStyle(fontSize: 10.5, color: surfaces.faint),
            ),
            const SizedBox(height: 16),
            _FieldLabel(isFtp ? 'FTP 主机' : '服务器地址'),
            const SizedBox(height: 8),
            TextField(
              controller: _serverController,
              autocorrect: false,
              keyboardType: isFtp ? TextInputType.url : TextInputType.url,
              decoration: InputDecoration(
                hintText: isFtp
                    ? 'ftp.example.com'
                    : 'https://example.com/dav/',
              ),
              onChanged: (_) => setState(() {
                if (_error != null) _error = null;
              }),
            ),
            if (isFtp) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '端口 21'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: surfaces.cardMuted.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'FTPS',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.onSurface,
                              ),
                            ),
                          ),
                          Switch(
                            value: _useTls,
                            onChanged: (value) =>
                                setState(() => _useTls = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const _FieldLabel('远端目录'),
            const SizedBox(height: 8),
            TextField(
              controller: _remoteController,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: isFtp ? '/luo-fanqie（需要提前创建）' : '番茄/（需要提前创建）',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: '用户名'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: '密码',
                      suffixIcon: IconButton(
                        tooltip: _passwordVisible ? '隐藏密码' : '显示密码',
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                        const Text(
                          '自动同步',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '本地任务或专注记录变化后，自动写入这个服务器。',
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
                    height: 1.5,
                    color: scheme.error,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _test,
                    child: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? '处理中…' : '保存并同步'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '密码只保存在本机应用沙盒中，不使用云端凭据；更换设备需要重新填写。',
              style: TextStyle(fontSize: 9.5, color: surfaces.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

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

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SyncServerType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : surfaces.cardMuted.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Text(
          type.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : surfaces.muted,
          ),
        ),
      ),
    );
  }
}
