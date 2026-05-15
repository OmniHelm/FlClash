import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const _appHelperService = 'FlClashHelperService';
const _configDirectoryName = 'config';
const _databaseDirectoryName = 'database';
const _profilesDirectoryName = 'profiles';
const _scriptsDirectoryName = 'scripts';
const _geoDirectoryName = 'geo';
const _portableFlagFileName = 'portable.flag';
const _portableEnvironmentKey = 'FLCLASH_PORTABLE';
const _portableDataDirectoryName = 'data';
const _portableCacheDirectoryName = 'cache';
const _portableTempDirectoryName = 'temp';
const _portableDownloadsDirectoryName = 'downloads';

class AppPath {
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  Completer<Directory> cacheDir = Completer();
  late String appDirPath;
  late final bool _isPortable;
  int _tempFileIndex = 0;

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    _isPortable = _resolvePortableMode();
    if (_isPortable) {
      dataDir.complete(_ensureDirectory(portableDataDirPath));
      tempDir.complete(_ensureDirectory(portableTempDirPath));
      downloadDir.complete(_ensureDirectory(portableDownloadsDirPath));
      cacheDir.complete(_ensureDirectory(portableCacheDirPath));
      return;
    }
    getApplicationSupportDirectory().then(dataDir.complete);
    getTemporaryDirectory().then(tempDir.complete);
    getDownloadsDirectory().then(downloadDir.complete);
    getApplicationCacheDirectory().then(cacheDir.complete);
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  String get executableExtension {
    return Platform.isWindows ? '.exe' : '';
  }

  bool get isPortable {
    return _isPortable;
  }

  String get executableDirPath {
    final currentExecutablePath = Platform.resolvedExecutable;
    return dirname(currentExecutablePath);
  }

  String get portableFlagPath {
    return join(executableDirPath, _portableFlagFileName);
  }

  String get portableDataDirPath {
    return join(executableDirPath, _portableDataDirectoryName);
  }

  String get portableCacheDirPath {
    return join(portableDataDirPath, _portableCacheDirectoryName);
  }

  String get portableTempDirPath {
    return join(executableDirPath, _portableTempDirectoryName);
  }

  String get portableDownloadsDirPath {
    return join(executableDirPath, _portableDownloadsDirectoryName);
  }

  String get corePath {
    return join(executableDirPath, 'FlClashCore$executableExtension');
  }

  String get helperPath {
    return join(executableDirPath, '$_appHelperService$executableExtension');
  }

  Future<String> get downloadDirPath async {
    final directory = await downloadDir.future;
    return directory.path;
  }

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get configDirPath async {
    return _ensureDataChildDirPath(_configDirectoryName);
  }

  Future<String> get databaseDirPath async {
    return _ensureDataChildDirPath(_databaseDirectoryName);
  }

  Future<String> get geoDirPath async {
    return _ensureDataChildDirPath(_geoDirectoryName);
  }

  Future<String> get databasePath async {
    final directory = await databaseDirPath;
    return join(directory, 'database.sqlite');
  }

  Future<String> get backupFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'backup.zip');
  }

  Future<String> get restoreDirPath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'restore');
  }

  Future<String> get tempFilePath async {
    final mTempDir = await tempDir.future;
    return join(mTempDir.path, _nextTempFileName());
  }

  Future<String> get lockFilePath async {
    final homeDirPath = await appPath.homeDirPath;
    return join(homeDirPath, 'FlClash.lock');
  }

  Future<String> get configFilePath async {
    final directory = await configDirPath;
    return join(directory, 'config.yaml');
  }

  Future<String> get sharedFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'shared.json');
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await configDirPath;
    return join(directory, 'shared_preferences.json');
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, _profilesDirectoryName);
  }

  Future<String> getProfilePath(String fileName) async {
    return join(await profilesPath, '$fileName.yaml');
  }

  Future<String> get scriptsDirPath async {
    return _ensureDataChildDirPath(_scriptsDirectoryName);
  }

  Future<String> getScriptPath(String fileName) async {
    final path = await scriptsDirPath;
    return join(path, '$fileName.js');
  }

  Future<String> getGeoFilePath(String fileName) async {
    final directory = await geoDirPath;
    return join(directory, fileName);
  }

  Future<String> getIconsCacheDir() async {
    final directory = await cacheDir.future;
    return join(directory.path, 'icons');
  }

  Future<String> getProvidersRootPath() async {
    final directory = await profilesPath;
    return join(directory, 'providers');
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id);
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id, type, _toMd5(url));
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }

  bool _resolvePortableMode() {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return false;
    }
    if (const bool.fromEnvironment('PORTABLE')) {
      return true;
    }
    final envValue = Platform.environment[_portableEnvironmentKey]
        ?.toLowerCase();
    if (envValue == '1' || envValue == 'true' || envValue == 'yes') {
      return true;
    }
    return File(portableFlagPath).existsSync();
  }

  Future<Directory> _ensureDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> _ensureDataChildDirPath(String childName) async {
    final dataDirectory = await dataDir.future;
    final directory = await _ensureDirectory(
      join(dataDirectory.path, childName),
    );
    return directory.path;
  }

  String _nextTempFileName() {
    final index = _tempFileIndex++;
    return 'temp${DateTime.now().microsecondsSinceEpoch}$index';
  }

  String _toMd5(String value) {
    final bytes = utf8.encode(value);
    return md5.convert(bytes).toString();
  }
}

final appPath = AppPath();
