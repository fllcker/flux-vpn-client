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
/// ВАЖНО (известное ограничение, актуально до появления Developer-аккаунта
/// и настоящего signed-хелпера): `osascript`/`do shell script` запускает
/// целевую команду через отдельный авторизованный `/bin/sh -c`, а не как
/// прямого child нашего процесса — `process.kill()` на возвращённом отсюда
/// `Process` убивает сам `osascript`, что обычно (но не гарантированно)
/// тянет за собой и его дочерний shell вместе с sing-box. На реальном Mac
/// это надо будет перепроверить и, если нужно, убивать sing-box отдельно
/// (например по имени процесса) — заменить на `runElevatedMacos` через
/// подписанный хелпер, когда появится Developer-аккаунт.
Future<Process> startElevatedMacos(String executable, List<String> arguments) {
  // AppleScript-строка собирается из отдельных shell-аргументов через ' '
  // как разделитель — ни исполняемый путь, ни аргументы sing-box-конфига
  // (сгенерированный нами JSON-файл во `fluxLogDirectory()`) не содержат
  // пользовательского ввода извне, так что экранирование кавычек тут не
  // нужно, но одинарные кавычки вокруг всей команды всё равно обязательны
  // для `do shell script`.
  final shellCommand = ([executable, ...arguments]).join(' ');
  final escaped = shellCommand.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return Process.start('osascript', [
    '-e',
    'do shell script "$escaped" with administrator privileges',
  ]);
}
