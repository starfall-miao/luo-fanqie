import 'package:shared_preferences/shared_preferences.dart';

/// 应用的最小持久化接口。
///
/// 保持同步读取，让控制器可以在构造时直接恢复数据；写入异步进行，
/// 避免阻塞 UI。测试中可以使用 [MemoryStorage] 完全脱离平台。
abstract interface class KeyValueStorage {
  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SharedPreferencesStorage implements KeyValueStorage {
  SharedPreferencesStorage(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesStorage> open() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesStorage(preferences);
  }

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}

/// 内存实现，用于测试与预览。
class MemoryStorage implements KeyValueStorage {
  MemoryStorage([Map<String, String>? seed])
    : _values = <String, String>{...?seed};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);
}
