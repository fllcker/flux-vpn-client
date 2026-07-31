import 'dart:io';

/// Поднятие `utun`-интерфейса (TUN-режим, `singbox_engine_macos.dart`)
/// требует root — Windows решает это через UAC-релонч всего `.exe`
/// (`windows_elevation.dart`); на macOS у приложения без подписанного
/// привилегированного хелпера или `SMAppService` (нужен платный Developer
/// аккаунт — см. TODO(dev-account) в `macos/Runner/*.entitlements`) нет
/// способа релончить *себя* с правами root через стандартный диалог, зато
/// можно поднять один конкретный процесс (`sing-box`) от root через
/// `osascript ... with administrator privileges`, не трогая всё приложение
/// целиком. Это стопгэп-аналог Windows "Варианта A", а не финальный дизайн —
/// правильный долгосрочный путь после появления аккаунта — `NetworkExtension`
/// (`NEPacketTunnelProvider`), которому root вообще не нужен.
///
/// Возвращает сам процесс `osascript` — вызывающая сторона (`stop()` в
/// `singbox_engine_macos.dart`) держит его, чтобы дождаться `exitCode`/убить.
///
/// ВАЖНО, подтверждено на реальном Маке (см. ROADMAP.md): `process.kill()`
/// на возвращённом отсюда `Process` НИКОГДА не убивает реальный `sing-box`.
/// `do shell script ... with administrator privileges` запускает целевую
/// команду не как child самого `osascript`, а через отдельный системный
/// `security_authtrampoline` (проверено через `ps -eo pid,ppid`: PPID
/// авторизованного `/bin/sh` — не `osascript`, а `launchd`) — они никогда не
/// были в одном дереве процессов. Без дополнительной elevated-команды
/// (см. [killElevatedMacos]) `sing-box` переживает "Отключить" и остаётся
/// висеть от root бесконечно — на реальном Маке за один вечер тестирования
/// накопилось 7 таких осиротевших процессов, каждый со своим `utun` и
/// маршрутами, конфликтующих друг с другом и с другими VPN-приложениями.
/// [logFilePath], если передан, — путь, куда сама elevated-shell (не наш
/// процесс) перенаправляет stdout/stderr целевой команды через `>`/`2>&1`.
/// Это не просто параноидальная страховка: `do shell script` возвращает
/// stdout вызванной команды только когда та команда САМА завершается — а
/// `sing-box` в TUN-режиме работает, пока его не убьют извне (кнопка
/// "Отключить"), и мы всегда останавливаем его убийством `osascript`, а не
/// ожиданием естественного завершения. Поэтому без явного файлового
/// редиректа `process.stdout`/`process.stderr` нашего `Process` (тот, что
/// возвращает эта функция — сам `osascript`, не `sing-box`) не получает
/// вообще ничего, а `_pipeLogs` в `singbox_engine_macos.dart` пишет пустой
/// файл при любом сценарии, включая реальные сбои — обнаружено при разборе
/// "TUN работает плохо" на реальном Маке, лог был пуст даже после падения.
Future<Process> startElevatedMacos(
  String executable,
  List<String> arguments, {
  String? logFilePath,
}) {
  // Каждый токен — в одинарных кавычках: `fluxLogDirectory()` живёт под
  // `~/Library/Application Support/flux/...`, и без кавычек пробел в
  // "Application Support" разбивает путь на два отдельных shell-аргумента,
  // после чего sing-box падает с "no such file or directory" на конфиге —
  // тот же класс бага, что уже был в geo_assets.dart (см. ROADMAP.md).
  var shellCommand = [executable, ...arguments].map(_shellQuote).join(' ');
  if (logFilePath != null) {
    shellCommand = '$shellCommand > ${_shellQuote(logFilePath)} 2>&1';
  }
  // Кавычки самого AppleScript-строкового литерала — экранируем то, что
  // осталось снаружи одинарных кавычек (сами одинарные кавычки для `do
  // shell script` не нужно трогать, значение внутри них шелл не парсит).
  final escaped = shellCommand.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return Process.start('osascript', [
    '-e',
    'do shell script "$escaped" with administrator privileges',
  ]);
}

/// Убивает elevated-процесс, запущенный через [startElevatedMacos], — по
/// уникальному фрагменту его командной строки, а не по PID/`Process.kill()`
/// (см. предупреждение выше, почему это не работает). [commandLineMatch] —
/// обычно путь к сгенерированному конфигу sing-box (`_configFile.path`,
/// см. `SingBoxEngineMacOS.stop()`) — он уникален на сессию и не совпадёт
/// ни с чем посторонним. Сам `pkill` идёт от обычного пользователя, а цель —
/// root-процесс, поэтому `pkill` тоже приходится поднимать через ещё один
/// диалог пароля (обычно без реального повторного ввода — macOS кеширует
/// авторизацию `do shell script` на несколько минут, а Отключить обычно
/// происходит вскоре после Подключить).
///
/// Не бросает исключение, если процесс уже не найден (`pkill` вернёт код
/// ошибки) или пользователь отклонил диалог — это best-effort уборка,
/// а не критичная часть отключения: `sing-box`, если и переживёт эту
/// попытку, будет пойман следующим запуском той же функции или замечен
/// пользователем как зависший процесс.
Future<void> killElevatedMacos(String commandLineMatch) async {
  final shellCommand = 'pkill -f ${_shellQuote(commandLineMatch)}';
  final escaped = shellCommand.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  final process = await Process.start('osascript', [
    '-e',
    'do shell script "$escaped" with administrator privileges',
  ]);
  await process.exitCode;
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
