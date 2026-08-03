import 'dart:io';

import '../core_abstraction/app_settings.dart';

/// Автозапуск при входе в macOS — LaunchAgent-plist в
/// `~/Library/LaunchAgents`, аналог Windows-реестрового `Run`-ключа
/// (`windows_autostart.dart`), но без разделения на `standard`/`elevated`:
/// у macOS нет отдельного "запусти с правами администратора при входе"
/// механизма, доступного без подписанного `SMAppService`/привилегированного
/// хелпера (которых пока нет — см. TODO(dev-account) в
/// `macos/Runner/*.entitlements`), поэтому `elevated` здесь настраивает тот
/// же LaunchAgent, что и `standard`.
const _agentLabel = 'rip.freeinternet.flux.autostart';

String _launchAgentPath() =>
    '${Platform.environment['HOME']}/Library/LaunchAgents/$_agentLabel.plist';

/// См. `windows_autostart.dart`'s `setAutoStartOnBoot` — тот же контракт
/// (синхронно чистит предыдущее состояние, потом настраивает новое), чтобы
/// `lib/app/autostart.dart` мог диспетчеризовать по платформе, не меняя
/// сигнатуру.
void setMacosAutoStartOnBoot({
  required AppAutoStartPrivilege privilege,
  required bool showWindow,
}) {
  if (!Platform.isMacOS) return;

  final file = File(_launchAgentPath());
  if (privilege == AppAutoStartPrivilege.none) {
    if (file.existsSync()) file.deleteSync();
    return;
  }

  final exePath = Platform.resolvedExecutable;
  final args = showWindow ? '' : '\n\t\t<string>--minimized</string>';
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>Label</key>
\t<string>$_agentLabel</string>
\t<key>ProgramArguments</key>
\t<array>
\t\t<string>$exePath</string>$args
\t</array>
\t<key>RunAtLoad</key>
\t<true/>
</dict>
</plist>
''');
}

/// См. `windows_autostart.dart`'s `isElevatedAutoStartActuallyRegistered` —
/// на macOS плист либо есть, либо нет, никакого асинхронного UAC-подобного
/// подтверждения не требуется, но сигнатура держится `Future<bool>` ради
/// общего диспетчера в `autostart.dart`.
Future<bool> isMacosAutoStartActuallyRegistered() async {
  if (!Platform.isMacOS) return false;
  return File(_launchAgentPath()).existsSync();
}
