import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_config.dart';
import 'remote_sync_store.dart';

/// 通用 WebDAV 同步。OpenAlist 也通过它的 WebDAV 端点走这个实现。
class WebDavSyncStore implements RemoteSyncStore {
  WebDavSyncStore({required this.config, http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final SyncConfig config;
  final http.Client _http;
  final bool _ownsClient;

  String get _authHeader {
    final raw = '${config.username}:${config.password}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  Map<String, String> get _headers => <String, String>{
    if (config.username.isNotEmpty) 'Authorization': _authHeader,
    'Accept': 'application/json, text/plain, */*',
  };

  Uri _folderUri() {
    var base = config.serverUrl.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      throw const SyncException('WebDAV / Alist 地址必须以 http:// 或 https:// 开头');
    }
    if (!base.endsWith('/')) base = '$base/';
    final remote = config.remotePath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final uri = Uri.parse(remote.isEmpty ? base : '$base$remote/');
    return uri;
  }

  Uri _fileUri() => _folderUri().resolve(config.fileName);

  @override
  Future<String?> download() async {
    final uri = _fileUri();
    final response = await _http.get(uri, headers: _headers);
    if (response.statusCode == 404) return null;
    _ensureSuccess(response, '读取 ${config.displayTarget}');
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  @override
  Future<void> upload(String content) async {
    final uri = _fileUri();
    final response = await _http.put(
      uri,
      headers: <String, String>{
        ..._headers,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(content),
    );
    _ensureSuccess(response, '写入 ${config.displayTarget}');
  }

  @override
  Future<void> test() async {
    final response = await _http.get(_fileUri(), headers: _headers);
    if (response.statusCode == 404 || response.statusCode == 200) {
      return;
    }
    _ensureSuccess(response, '连接 ${config.displayTarget}');
  }

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final code = response.statusCode;
    final message = switch (code) {
      401 || 403 => '$action失败：用户名或密码不正确，或没有目录权限',
      404 => '$action失败：远端目录不存在，请先创建目录',
      405 => '$action失败：服务器不允许该 WebDAV 方法',
      409 => '$action失败：远端目录结构不完整',
      >= 500 => '$action失败：文件服务器暂时不可用（HTTP $code）',
      _ => '$action失败（HTTP $code）',
    };
    throw SyncException(message, statusCode: code);
  }

  @override
  void close() {
    if (_ownsClient) _http.close();
  }
}
