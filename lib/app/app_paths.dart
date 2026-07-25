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
