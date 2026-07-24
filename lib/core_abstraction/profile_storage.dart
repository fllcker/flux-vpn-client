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
        ? '$appData\\flux'
        : '${Directory.systemTemp.path}\\flux';
    return File('$dir\\profile.json');
  }

  /// Старый путь хранения от переименования проекта (vpn_client → flux) —
  /// используется только для одноразовой миграции в [load], чтобы профиль,
  /// уже сохранённый пользователем, не потерялся при апдейте.
  File _legacyFile() {
    final appData = Platform.environment['APPDATA'];
    final dir = appData != null
        ? '$appData\\vpn_client'
        : '${Directory.systemTemp.path}\\vpn_client';
    return File('$dir\\profile.json');
  }

  CoreConfig load() {
    final file = _file();
    final source = file.existsSync() ? file : _legacyFile();
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
