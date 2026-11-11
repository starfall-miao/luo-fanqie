import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_snapshot.dart';

class SyncException implements Exception {
  const SyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RemoteSyncData {
  const RemoteSyncData({required this.gistId, required this.snapshot});

  final String? gistId;
  final SyncSnapshot? snapshot;
}

/// 远端同步存储的抽象，方便在测试中替换成内存实现。
abstract interface class RemoteSyncStore {
  Future<RemoteSyncData> pull();

  /// 返回远端文档 id（Gist 场景下是 gist id）。
  Future<String> push(SyncSnapshot snapshot);

  void close();
}

/// 使用 GitHub Gist 作为跨设备同步存储。
///
/// 用户只需要提供一个带 gist 权限的个人访问令牌。首次同步会自动创建
/// 一个私密 Gist；其他设备用同一个账号的令牌即可自动找到它。
class GistSyncClient implements RemoteSyncStore {
  GistSyncClient({
    required this.token,
    this.gistId,
    http.Client? httpClient,
    this.fileName = 'luo-fanqie-sync.json',
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const _apiBase = 'https://api.github.com';
  static const _description = '落·番茄 跨设备同步（自动创建，请勿删除）';

  final String token;
  final String fileName;
  final http.Client _http;
  final bool _ownsClient;
  String? gistId;

  Map<String, String> get _headers => <String, String>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json; charset=utf-8',
  };

  @override
  Future<RemoteSyncData> pull() async {
    if (token.trim().isEmpty) {
      throw const SyncException('请先填写 GitHub Token');
    }
    final id = gistId ?? await _findGist();
    if (id == null) {
      return const RemoteSyncData(gistId: null, snapshot: null);
    }
    final response = await _http.get(
      Uri.parse('$_apiBase/gists/$id'),
      headers: _headers,
    );
    _ensureSuccess(response, '读取云端同步数据');
    final body = _decodeBody(response);
    final files = body['files'];
    if (files is! Map || files[fileName] is! Map) {
      throw const SyncException('云端 Gist 中还没有落·番茄的同步文件');
    }
    final file = Map<String, dynamic>.from(files[fileName] as Map);
    var content = file['content'] as String? ?? '';
    final truncated = file['truncated'] == true;
    if (truncated || content.isEmpty) {
      final rawUrl = file['raw_url'] as String?;
      if (rawUrl != null) {
        final raw = await _http.get(Uri.parse(rawUrl), headers: _headers);
        _ensureSuccess(raw, '读取云端同步内容');
        content = raw.body;
      }
    }
    if (content.trim().isEmpty) {
      return RemoteSyncData(gistId: id, snapshot: null);
    }
    try {
      gistId = id;
      return RemoteSyncData(gistId: id, snapshot: SyncSnapshot.decode(content));
    } on FormatException {
      throw const SyncException('云端同步数据已损坏，请检查 Gist 内容');
    }
  }

  @override
  Future<String> push(SyncSnapshot snapshot) async {
    if (token.trim().isEmpty) {
      throw const SyncException('请先填写 GitHub Token');
    }
    final content = snapshot.encode();
    if (content.length > 950 * 1024) {
      throw const SyncException('同步数据超过 1MB，暂时无法写入 Gist');
    }
    final id = gistId ?? await _findGist();
    final payload = <String, dynamic>{
      'description': _description,
      'public': false,
      'files': <String, dynamic>{
        fileName: <String, dynamic>{'content': content},
      },
    };
    if (id == null) {
      final response = await _http.post(
        Uri.parse('$_apiBase/gists'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      _ensureSuccess(response, '创建云端同步 Gist');
      final body = _decodeBody(response);
      final createdId = body['id'] as String?;
      if (createdId == null) {
        throw const SyncException('GitHub 未返回 Gist ID');
      }
      gistId = createdId;
      return createdId;
    }

    final response = await _http.patch(
      Uri.parse('$_apiBase/gists/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, '写入云端同步数据');
    gistId = id;
    return id;
  }

  Future<String?> _findGist() async {
    final response = await _http.get(
      Uri.parse('$_apiBase/gists?per_page=100'),
      headers: _headers,
    );
    _ensureSuccess(response, '查找云端同步 Gist');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return null;
    for (final item in decoded.whereType<Map>()) {
      if (item['description'] != _description) continue;
      final files = item['files'];
      if (files is Map && files.containsKey(fileName)) {
        final id = item['id'] as String?;
        if (id != null) return id;
      }
    }
    return null;
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 统一走下面的异常。
    }
    throw const SyncException('GitHub 返回了无法解析的数据');
  }

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final status = response.statusCode;
    String message;
    if (status == 401) {
      message = 'GitHub Token 无效或已过期，请检查后重试';
    } else if (status == 403) {
      message = 'GitHub 没有权限或已触发速率限制，请稍后再试';
    } else if (status == 404) {
      message = '找不到同步 Gist，可能已被删除';
    } else if (status >= 500) {
      message = 'GitHub 服务暂时不可用（$status）';
    } else {
      message = '$action失败（HTTP $status）';
    }
    throw SyncException(message, statusCode: status);
  }

  @override
  void close() {
    if (_ownsClient) _http.close();
  }
}
