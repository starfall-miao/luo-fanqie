class SyncException implements Exception {
  const SyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 用户自建文件服务器的最小同步接口。
abstract interface class RemoteSyncStore {
  /// 返回远端文件内容；文件不存在时返回 null。
  Future<String?> download();

  Future<void> upload(String content);

  /// 验证地址、凭据和目录是否可用。
  Future<void> test();

  void close();
}
