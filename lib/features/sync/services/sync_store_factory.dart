import 'package:http/http.dart' as http;

import '../models/sync_config.dart';
import 'ftp/ftp_sync_store_stub.dart'
    if (dart.library.io) 'ftp/ftp_sync_store_io.dart'
    as ftp_impl;
import 'remote_sync_store.dart';
import 'webdav_sync_store.dart';

RemoteSyncStore createSyncStore(SyncConfig config, {http.Client? httpClient}) {
  return switch (config.type) {
    SyncServerType.webdav || SyncServerType.alist => WebDavSyncStore(
      config: config,
      httpClient: httpClient,
    ),
    SyncServerType.ftp => ftp_impl.createFtpSyncStore(config),
  };
}
