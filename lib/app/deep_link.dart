import 'dart:io';

import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import 'package:win32_registry/win32_registry.dart';

/// Диплинк-схема приложения — как `vless://`, `sing-box://` и подобные в
/// других клиентах. `flux://add/<url-encoded ссылка>` открывает диалог
/// добавления сервера с уже подставленной ссылкой.
const fluxUriScheme = 'flux';

/// Регистрирует `flux://` как обработчик URL-протокола в реестре текущего
/// пользователя (`HKCU\Software\Classes\flux`) — не требует прав
/// администратора. Идемпотентно: перезаписывает путь к .exe при каждом
/// запуске на случай, если приложение переместили/пересобрали.
void registerFluxUriProtocolIfNeeded() {
  if (!Platform.isWindows) return;

  final exePath = Platform.resolvedExecutable;
  final protocolKey = CURRENT_USER.create('Software\\Classes\\$fluxUriScheme');
  protocolKey
    ..setValue('', const RegistryValue.string('URL:Flux Protocol'))
    ..setValue('URL Protocol', const RegistryValue.string(''));

  final commandKey = protocolKey.create('shell\\open\\command');
  commandKey.setValue('', RegistryValue.string('"$exePath" "%1"'));
}

/// Достаёт ссылку (`vless://...` или `https://...`) из аргумента вида
/// `flux://add/<...>` — тело диплинка может быть как обычным URL, так и
/// URL-encoded строкой.
String? parseFluxDeepLink(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme.toLowerCase() != fluxUriScheme) return null;

  // `flux://add/vless%3A%2F%2F...` -> host="add", path="/vless://...".
  // `flux://add?url=...` -> host="add", query "url".
  if (uri.queryParameters['url'] case final fromQuery?
      when fromQuery.isNotEmpty) {
    return fromQuery;
  }

  final rest = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
  if (rest.isEmpty) return null;

  try {
    return Uri.decodeComponent(rest);
  } catch (_) {
    return rest;
  }
}

/// Первый аргумент командной строки, похожий на диплинк `flux://...` —
/// Windows передаёт зарегистрированный URL первым (и обычно единственным)
/// аргументом при запуске приложения через протокол.
String? extractFluxDeepLinkFromArgs(List<String> args) {
  for (final arg in args) {
    if (arg.toLowerCase().startsWith('$fluxUriScheme://')) return arg;
  }
  return null;
}

// --- Android/macOS -----------------------------------------------------
//
// Регистрация схемы — не в Dart: в `android/app/src/main/AndroidManifest.
// xml` (intent-filter с `android:scheme="flux"` на MainActivity) для
// Android, и в `macos/Runner/Info.plist` (`CFBundleURLTypes`) для macOS. Ни
// у Android, ни у macOS нет Windows-style второго процесса/loopback-IPC
// (см. `single_instance.dart`) — Android переиспользует единственную
// Activity (`launchMode="singleTop"`) и присылает повторные ссылки через
// `onNewIntent` (`MainActivity.kt`), macOS точно так же переиспользует
// единственный процесс (`LSMultipleInstancesProhibited` в Info.plist) и
// присылает их через Apple Event `kAEGetURL`, перехваченный в
// `AppDelegate.swift`. Оба шлют результат в Dart одинаково — через один и
// тот же канал, поэтому обвязка тут общая, а не дублируется по платформе.
const _nativeDeepLinkChannel = MethodChannel('flux/deeplink');
const _nativeDeepLinkEventChannel = EventChannel('flux/deeplink/stream');

Future<String?> nativeInitialDeepLink() async {
  if (!Platform.isAndroid && !Platform.isMacOS) return null;
  try {
    return await _nativeDeepLinkChannel.invokeMethod<String>('getInitialLink');
  } catch (_) {
    return null;
  }
}

Stream<String> get nativeDeepLinkStream {
  if (!Platform.isAndroid && !Platform.isMacOS) return const Stream.empty();
  return _nativeDeepLinkEventChannel.receiveBroadcastStream().map(
    (event) => event as String,
  );
}
