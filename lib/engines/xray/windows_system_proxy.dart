import 'dart:ffi';

import 'package:win32_registry/win32_registry.dart';

const _internetSettingsPath =
    r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

/// Прописывает системный прокси Windows на локальный HTTP-инбаунд
/// xray-core — см. PLAN.md, "Системная интеграция VPN на Windows",
/// Вариант B. Один HTTP-прокси на все протоколы: xray-core принимает
/// CONNECT и проксирует HTTPS через тот же порт, отдельный SOCKS-порт
/// системе не сообщается (WinINet/большинство Windows-приложений не умеют
/// системный SOCKS).
void enableWindowsSystemProxy({required int httpPort}) {
  final key = CURRENT_USER.create(_internetSettingsPath);
  try {
    key.setValue('ProxyEnable', const RegistryValue.dword(1));
    key.setValue('ProxyServer', RegistryValue.string('127.0.0.1:$httpPort'));
  } finally {
    key.close();
  }
  _notifySystemProxyChanged();
}

void disableWindowsSystemProxy() {
  final key = CURRENT_USER.create(_internetSettingsPath);
  try {
    key.setValue('ProxyEnable', const RegistryValue.dword(0));
  } finally {
    key.close();
  }
  _notifySystemProxyChanged();
}

// package:win32 не биндит wininet.dll (не входит в сгенерированный набор),
// поэтому InternetSetOption вызываем напрямую через dart:ffi. Без этого
// уже запущенные процессы (например открытый браузер) не увидят новый
// прокси до перезапуска.

typedef _InternetSetOptionWNative =
    Int32 Function(
      IntPtr hInternet,
      Uint32 dwOption,
      Pointer<Void> lpBuffer,
      Uint32 dwBufferLength,
    );
typedef _InternetSetOptionWDart =
    int Function(
      int hInternet,
      int dwOption,
      Pointer<Void> lpBuffer,
      int dwBufferLength,
    );

const _internetOptionSettingsChanged = 39;
const _internetOptionRefresh = 37;

final _internetSetOptionW = DynamicLibrary.open(
  'wininet.dll',
).lookupFunction<_InternetSetOptionWNative, _InternetSetOptionWDart>(
  'InternetSetOptionW',
);

void _notifySystemProxyChanged() {
  _internetSetOptionW(0, _internetOptionSettingsChanged, nullptr, 0);
  _internetSetOptionW(0, _internetOptionRefresh, nullptr, 0);
}
