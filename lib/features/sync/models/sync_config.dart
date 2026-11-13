import 'dart:convert';

/// 同步协议类型。所有目标都是用户自己填写的文件服务器。
enum SyncServerType { webdav, alist, ftp }

extension SyncServerTypeX on SyncServerType {
  String get label => switch (this) {
    SyncServerType.webdav => 'WebDAV',
    SyncServerType.alist => 'OpenAlist',
    SyncServerType.ftp => 'FTP / FTPS',
  };

  String get hint => switch (this) {
    SyncServerType.webdav =>
      '例如 https://dav.example.com/remote.php/dav/files/me/番茄/',
    SyncServerType.alist =>
      '填写 Alist 的 WebDAV 地址，例如 https://alist.example.com/dav/番茄/',
    SyncServerType.ftp => '例如 ftp.example.com，默认端口 21',
  };

  bool get isHttp => this != SyncServerType.ftp;
}

class SyncConfig {
  const SyncConfig({
    required this.type,
    required this.serverUrl,
    this.port = 21,
    this.username = '',
    this.password = '',
    this.remotePath = '',
    this.useTls = false,
    this.autoSync = false,
  });

  final SyncServerType type;

  /// WebDAV / Alist 的完整目录 URL；FTP 的主机名。
  final String serverUrl;

  final int port;
  final String username;
  final String password;

  /// 服务器上的子目录，留空表示根目录。
  final String remotePath;

  /// FTP 是否使用 FTPS；对 WebDAV/Alist 无意义。
  final bool useTls;

  final bool autoSync;

  bool get isConfigured => serverUrl.trim().isNotEmpty;

  String get fileName => 'luo-fanqie-sync.json';

  String get displayTarget => switch (type) {
    SyncServerType.webdav ||
    SyncServerType.alist => Uri.tryParse(serverUrl)?.host ?? serverUrl,
    SyncServerType.ftp => serverUrl,
  };

  SyncConfig copyWith({
    SyncServerType? type,
    String? serverUrl,
    int? port,
    String? username,
    String? password,
    String? remotePath,
    bool? useTls,
    bool? autoSync,
  }) {
    return SyncConfig(
      type: type ?? this.type,
      serverUrl: serverUrl ?? this.serverUrl,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      useTls: useTls ?? this.useTls,
      autoSync: autoSync ?? this.autoSync,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'serverUrl': serverUrl,
    'port': port,
    'username': username,
    'password': password,
    'remotePath': remotePath,
    'useTls': useTls,
    'autoSync': autoSync,
  };

  String encode() => jsonEncode(toJson());

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      type: SyncServerType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => SyncServerType.webdav,
      ),
      serverUrl: json['serverUrl'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 21,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '',
      useTls: json['useTls'] as bool? ?? false,
      autoSync: json['autoSync'] as bool? ?? false,
    );
  }

  static SyncConfig? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SyncConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 损坏配置回到未配置状态。
    }
    return null;
  }
}
