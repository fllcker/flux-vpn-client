import 'dart:io';

import '../core_abstraction/app_settings.dart';
import 'macos_autostart.dart';
import 'windows_autostart.dart' as windows;

/// Диспетчер автозапуска по платформе — `settings_page.dart` не должно
/// знать, реестр это (Windows) или LaunchAgent-plist (macOS); на Android
/// (нет десктопного автозапуска вовсе) обе стороны — no-op.
void setAutoStartOnBoot({
  required AppAutoStartPrivilege privilege,
  required bool showWindow,
}) {
  if (Platform.isWindows) {
    windows.setAutoStartOnBoot(privilege: privilege, showWindow: showWindow);
  } else if (Platform.isMacOS) {
    setMacosAutoStartOnBoot(privilege: privilege, showWindow: showWindow);
  }
}

Future<bool> isElevatedAutoStartActuallyRegistered() {
  if (Platform.isWindows) {
    return windows.isElevatedAutoStartActuallyRegistered();
  }
  if (Platform.isMacOS) return isMacosAutoStartActuallyRegistered();
  return Future.value(false);
}
