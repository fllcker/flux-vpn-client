import 'dart:io';

/// Каталог данных приложения — тот же `%AppData%\flux`, в котором лежат
/// профиль и настройки (см. `profile_storage.dart`, `app_settings_storage.dart`).
String fluxDataDirectoryPath() {
  final appData = Platform.environment['APPDATA'];
  return appData != null
      ? '$appData\\flux'
      : '${Directory.systemTemp.path}\\flux';
}

/// Каталог логов ядер. Раньше логи и временные конфиги сыпались прямо в
/// `%TEMP%`, вперемешку с чужими файлами, и «открыть папку с логами» означало
/// бы открыть свалку на несколько тысяч файлов. Отдельный каталог рядом с
/// профилем решает это и заодно переживает очистку `%TEMP%` уборщиком диска.
Directory fluxLogDirectory() =>
    Directory('${fluxDataDirectoryPath()}\\logs');

/// Создаёт каталог логов, если его ещё нет, и возвращает путь. Вызывается
/// перед открытием файла лога — иначе первый же запуск ядра падал бы на
/// отсутствующем каталоге.
String ensureFluxLogDirectory() {
  final dir = fluxLogDirectory();
  dir.createSync(recursive: true);
  return dir.path;
}

/// Открывает каталог логов в проводнике. Не ждём результата и не считаем
/// ненулевой код ошибкой: `explorer.exe` возвращает 1 даже когда окно
/// открылось, так что проверять тут нечего.
Future<void> openFluxLogDirectory() async {
  final path = ensureFluxLogDirectory();
  await Process.start('explorer.exe', [path]);
}

/// Каталог geoip/geosite баз и сгенерированных из них sing-box rule-set'ов
/// (ROADMAP.md, треки 20/21) — раньше эти файлы были вшиты в сборку рядом с
/// `xray.exe`, теперь качаются в рантайме и живут вместе с остальными
/// пользовательскими данными.
Directory fluxGeoDirectory() => Directory('${fluxDataDirectoryPath()}\\geo');

/// Создаёт каталог geoip/geosite, если его ещё нет, и возвращает путь — тот
/// же паттерн, что и [ensureFluxLogDirectory].
String ensureFluxGeoDirectory() {
  final dir = fluxGeoDirectory();
  dir.createSync(recursive: true);
  return dir.path;
}

/// Каталог сгенерированных из geoip.dat/geosite.dat sing-box rule-set'ов
/// (ROADMAP.md, трек 21, `lib/engines/singbox/geo_ruleset_cache.dart`) —
/// подкаталог geoip/geosite, а не рядом с ним: это производные файлы,
/// которые можно целиком удалить и перегенерировать, в отличие от самих
/// `.dat`.
String ensureFluxGeoRuleSetDirectory() {
  final dir = Directory('${ensureFluxGeoDirectory()}\\rulesets');
  dir.createSync(recursive: true);
  return dir.path;
}
