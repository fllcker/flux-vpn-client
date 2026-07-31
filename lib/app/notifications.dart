import 'dart:io';

import 'package:local_notifier/local_notifier.dart';

/// Тонкая обёртка над `local_notifier` (тот же издатель leanflutter, что и
/// уже используемые `tray_manager`/`window_manager`) — системные
/// Windows-уведомления при подключении/отключении/ошибке, см. ROADMAP.md,
/// трек 25. Реальные тексты собирает вызывающая сторона
/// (`connection_notifications.dart`), этот файл не знает про
/// `ConnectionUiState` вообще.
Future<void> initLocalNotifier() async {
  if (!Platform.isWindows && !Platform.isMacOS) return;
  await localNotifier.setup(appName: 'Flux');
}

void showFluxNotification({required String title, String? body}) {
  if (!Platform.isWindows && !Platform.isMacOS) return;
  LocalNotification(title: title, body: body ?? '').show();
}
