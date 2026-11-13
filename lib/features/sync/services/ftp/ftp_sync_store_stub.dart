import '../../models/sync_config.dart';
import '../remote_sync_store.dart';

RemoteSyncStore createFtpSyncStore(SyncConfig config) =>
    const UnsupportedFtpSyncStore();

class UnsupportedFtpSyncStore implements RemoteSyncStore {
  const UnsupportedFtpSyncStore();

  Never _unsupported() =>
      throw const SyncException('FTP 仅支持 Android / iOS / 桌面端，Web 请使用 WebDAV');

  @override
  Future<String?> download() async => _unsupported();

  @override
  Future<void> upload(String content) async => _unsupported();

  @override
  Future<void> test() async => _unsupported();

  @override
  void close() {}
}
