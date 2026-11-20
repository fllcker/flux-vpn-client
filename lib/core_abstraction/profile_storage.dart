import 'dart:convert';
import 'dart:io';

import 'core_config.dart';

/// Простое хранилище профиля на диске — `%AppData%\flux\profile.json` на
/// Windows. Без бэкапов/миграций схемы пока — см. PLAN.md, "обратная
/// совместимость Magic JSON" для правил на будущее, когда появятся версии
/// выше 1.
class ProfileStorage {
  const ProfileStorage();

  File _file() {
    final appData = Platform.environment['APPDATA'];
    final dir = appData != null
        ? '$appData\\flux_tracker'
        : '${Directory.systemTemp.path}\\flux_tracker';
    return File('$dir\\profile.json');
  }

  CoreConfig load() {
    final file = _file();
    final source = file;
    if (!source.existsSync()) return const CoreConfig();
    try {
      final json =
          jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
      return CoreConfig.fromJson(json);
    } catch (_) {
      // Битый/несовместимый файл — не роняем приложение, начинаем с пустого
      // профиля.
      return const CoreConfig();
    }
  }

  void save(CoreConfig config) {
    final file = _file();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(config.toJson()));
  }
}

const profileStorage = ProfileStorage();
