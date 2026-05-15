import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

abstract class PreferencesStore {
  int? getInt(String key);

  Future<bool> setInt(String key, int value);

  String? getString(String key);

  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);

  Future<bool> clear();
}

class SharedPreferencesStore implements PreferencesStore {
  final SharedPreferences preferences;

  SharedPreferencesStore(this.preferences);

  @override
  int? getInt(String key) {
    return preferences.getInt(key);
  }

  @override
  Future<bool> setInt(String key, int value) {
    return preferences.setInt(key, value);
  }

  @override
  String? getString(String key) {
    return preferences.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) {
    return preferences.setString(key, value);
  }

  @override
  Future<bool> remove(String key) {
    return preferences.remove(key);
  }

  @override
  Future<bool> clear() {
    return preferences.clear();
  }
}

class FilePreferencesStore implements PreferencesStore {
  final File file;
  final Map<String, Object?> _values;

  FilePreferencesStore._internal(this.file, this._values);

  static Future<FilePreferencesStore> create(String path) async {
    final file = File(path);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.writeAsString('{}', flush: true);
      return FilePreferencesStore._internal(file, {});
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return FilePreferencesStore._internal(file, {});
    }
    final data = json.decode(content);
    if (data is! Map) {
      throw const FormatException('Invalid preferences data');
    }
    return FilePreferencesStore._internal(
      file,
      data.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }

  @override
  int? getInt(String key) {
    final value = _values[key];
    return value is int ? value : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return await _save();
  }

  @override
  String? getString(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return await _save();
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return await _save();
  }

  @override
  Future<bool> clear() async {
    _values.clear();
    return await _save();
  }

  Future<bool> _save() async {
    await file.writeAsString(json.encode(_values), flush: true);
    return true;
  }
}

class Preferences {
  static Preferences? _instance;
  Completer<PreferencesStore?> preferencesStoreCompleter = Completer();

  Future<bool> get isInit async =>
      await preferencesStoreCompleter.future != null;

  Preferences._internal() {
    _initStore()
        .then((value) => preferencesStoreCompleter.complete(value))
        .onError((_, _) => preferencesStoreCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<int> getVersion() async {
    final preferences = await preferencesStoreCompleter.future;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await preferencesStoreCompleter.future;
    await preferences?.setInt('version', version);
  }

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await preferencesStoreCompleter.future;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await preferencesStoreCompleter.future;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await preferencesStoreCompleter.future;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await preferencesStoreCompleter.future;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (_) {
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await preferencesStoreCompleter.future;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await preferencesStoreCompleter.future;
    await sharedPreferencesIns?.clear();
  }

  Future<PreferencesStore> _initStore() async {
    if (appPath.isPortable) {
      return await FilePreferencesStore.create(
        await appPath.sharedPreferencesPath,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesStore(preferences);
  }
}

final preferences = Preferences();
