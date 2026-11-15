import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> _directory() async {
  final base = await getApplicationSupportDirectory();
  final directory = Directory('${base.path}/custom_sounds');
  if (!directory.existsSync()) directory.createSync(recursive: true);
  return directory;
}

Future<String?> saveCustomSoundFileImpl(
  String fileName,
  List<int> bytes,
) async {
  try {
    final directory = await _directory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<String?> customSoundFilePathImpl(String fileName) async {
  try {
    final directory = await _directory();
    final file = File('${directory.path}/$fileName');
    return file.existsSync() ? file.path : null;
  } catch (_) {
    return null;
  }
}

Future<void> deleteCustomSoundFileImpl(String fileName) async {
  try {
    final directory = await _directory();
    final file = File('${directory.path}/$fileName');
    if (file.existsSync()) await file.delete();
  } catch (_) {
    // 忽略清理失败。
  }
}
