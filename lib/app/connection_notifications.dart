import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core_abstraction/app_settings_provider.dart';
import '../features/connection/connection_controller.dart';
import '../features/connection/connection_state.dart';
import '../l10n/strings.dart';
import 'notifications.dart';

/// Слушает `connectionControllerProvider` и шлёт системные Windows-
/// уведомления на подключение/отключение/ошибку — см. ROADMAP.md, трек 25.
/// Тот же паттерн, что `tray.dart`'s `FluxTray`: работает через явный
/// [ProviderContainer] (см. `main.dart`), не `WidgetRef` — живёт вне дерева
/// виджетов.
///
/// Не различает "пользователь отключился сам" от "туннель просто оборвался"
/// — `ConnectionController` в обоих случаях уходит в `ConnectionIdle`
/// одинаково (см. doc-комментарий в файле плана/ROADMAP.md, трек 25) —
/// показываем одно и то же "Отключено" на любой переход из
/// подключённого/подключающегося состояния в `Idle`.
class ConnectionNotifications {
  final ProviderContainer container;

  ConnectionNotifications(this.container);

  void init() {
    if (!Platform.isWindows) return;
    container.listen<ConnectionUiState>(
      connectionControllerProvider,
      _handle,
    );
  }

  void _handle(ConnectionUiState? previous, ConnectionUiState next) {
    if (!container.read(appSettingsProvider).showNotifications) return;

    switch (next) {
      case ConnectionConnected(:final serverName, :final mode):
        showFluxNotification(
          title: S.notificationConnectedTitle,
          body: S.notificationConnectedBody(serverName, mode),
        );
      case ConnectionIdle():
        if (previous is ConnectionConnected ||
            previous is ConnectionConnecting ||
            previous is ConnectionStopping) {
          showFluxNotification(title: S.notificationDisconnectedTitle);
        }
      case ConnectionError(:final message):
        showFluxNotification(
          title: S.notificationErrorTitle,
          body: message,
        );
      case ConnectionConnecting():
      case ConnectionStopping():
        break;
    }
  }
}
