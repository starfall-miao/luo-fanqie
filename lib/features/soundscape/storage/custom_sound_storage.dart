import 'custom_sound_storage_stub.dart'
    if (dart.library.io) 'custom_sound_storage_io.dart';

Future<String?> saveCustomSoundFile(String fileName, List<int> bytes) =>
    saveCustomSoundFileImpl(fileName, bytes);

Future<String?> customSoundFilePath(String fileName) =>
    customSoundFilePathImpl(fileName);

Future<void> deleteCustomSoundFile(String fileName) =>
    deleteCustomSoundFileImpl(fileName);
