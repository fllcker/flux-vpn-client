import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';

/// Хранилище настроек приложения — отдельный файл от профиля серверов
/// (`profile_storage.dart`), тот же каталог `%AppData%\flux`.
class AppSettingsStorage {
  const AppSettingsStorage();

  File _file() {
    final appData = Platform.environment['APPDATA'];
    final dir = appData != null
        ? '$appData\\flux'
        : '${Directory.systemTemp.path}\\flux';
    return File('$dir\\settings.json');
  }

  AppSettings load() {
    final file = _file();
    if (!file.existsSync()) return const AppSettings();
    try {
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  void save(AppSettings settings) {
    final file = _file();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(settings.toJson()));
  }
}

const appSettingsStorage = AppSettingsStorage();
