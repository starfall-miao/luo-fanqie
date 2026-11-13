import 'dart:convert';
import 'dart:typed_data';

import 'package:ftpconnect/ftpconnect.dart';

import '../../models/sync_config.dart';
import '../remote_sync_store.dart';

RemoteSyncStore createFtpSyncStore(SyncConfig config) => FtpSyncStore(config);

class FtpSyncStore implements RemoteSyncStore {
  FtpSyncStore(this.config);

  final SyncConfig config;
  FTPConnect? _client;

  String get _host {
    var host = config.serverUrl.trim();
    host = host.replaceFirst(RegExp(r'^(ftp|ftps)://'), '');
    host = host.split('/').first;
    if (host.isEmpty) {
      throw const SyncException('请填写 FTP 服务器地址');
    }
    return host;
  }

  Future<FTPConnect> _connect() async {
    if (_client != null) return _client!;
    final client = FTPConnect(
      _host,
      port: config.port,
      user: config.username,
      pass: config.password,
      showLog: false,
      timeout: 20,
      securityType: config.useTls ? SecurityType.ftps : SecurityType.ftp,
    );
    final connected = await client.connect();
    if (!connected) {
      throw const SyncException('FTP 连接失败');
    }
    final remotePath = config.remotePath.trim();
    if (remotePath.isNotEmpty) {
      final changed = await client.changeDirectory(remotePath);
      if (!changed) {
        await client.disconnect();
        throw const SyncException('FTP 远端目录不存在，请先在服务器上创建它');
      }
    }
    _client = client;
    return client;
  }

  @override
  Future<String?> download() async {
    final client = await _connect();
    try {
      final bytes = await client.downloadToBytes(config.fileName);
      return utf8.decode(bytes, allowMalformed: true);
    } on FTPConnectException catch (error) {
      final response = error.response ?? '';
      if (response.startsWith('550') || error.toString().contains('550')) {
        return null;
      }
      throw SyncException('读取 FTP 文件失败：${error.message}');
    } catch (error) {
      throw SyncException('读取 FTP 文件失败：$error');
    }
  }

  @override
  Future<void> upload(String content) async {
    final client = await _connect();
    final ok = await client.uploadData(
      Uint8List.fromList(utf8.encode(content)),
      config.fileName,
    );
    if (!ok) throw const SyncException('FTP 写入失败');
  }

  @override
  Future<void> test() async {
    await _connect();
  }

  @override
  void close() {
    final client = _client;
    _client = null;
    client?.disconnect();
  }
}
