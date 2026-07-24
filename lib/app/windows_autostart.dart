import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// Автозапуск при старте Windows — `HKCU\Software\Microsoft\Windows\
/// CurrentVersion\Run`, не требует прав администратора (в отличие от
/// `HKLM`). См. ROADMAP.md, трек 7.
const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _runValueName = 'Flux';

/// Включает/выключает автозапуск, синхронно с изменением настройки
/// `autoStartOnBoot` (см. `app_settings.dart`). `--minimized` — чтобы
/// автозапуск открывал приложение сразу свёрнутым в трей, не мозоля окном
/// при входе в систему (см. `main.dart`).
void setAutoStartOnBoot(bool enabled) {
  if (!Platform.isWindows) return;

  final key = CURRENT_USER.create(_runKeyPath);
  if (enabled) {
    final exePath = Platform.resolvedExecutable;
    key.setValue(_runValueName, RegistryValue.string('"$exePath" --minimized'));
  } else {
    try {
      key.removeValue(_runValueName);
    } catch (_) {
      // Значения не было — уже выключено, ничего делать не нужно.
    }
  }
}
