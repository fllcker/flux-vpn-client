import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core_abstraction/connection_session.dart';
import '../core_abstraction/core_config_provider.dart';
import '../l10n/strings.dart';
import '../features/connection/connection_controller.dart';
import '../features/connection/connection_state.dart';
import '../features/servers/flatten_leaves.dart';
import '../features/servers/selected_server_provider.dart';

/// Иконка в трее + меню (Открыть / Подключить-Отключить / Выход) — см.
/// ROADMAP.md, трек 7. Закрытие окна крестиком/Alt+F4 сворачивает в трей
/// (см. `main.dart`, `windowManager.setPreventClose(true)` +
/// `WindowListener.onWindowClose`); полный выход — только через пункт
/// "Выход" здесь.
///
/// Работает через явный [ProviderContainer] (см. `main.dart`,
/// `UncontrolledProviderScope`), а не через `WidgetRef` — обработчики кликов
/// по трею живут вне дерева виджетов.
class FluxTray with TrayListener {
  final ProviderContainer container;

  FluxTray(this.container);

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;

    trayManager.addListener(this);
    await _updateIcon();
    await trayManager.setToolTip('Flux');
    await _updateMenu();

    container.listen(connectionControllerProvider, (_, _) {
      _updateIcon();
      _updateMenu();
    });
  }

  /// Иконка меняется по режиму активного подключения (ROADMAP.md, трек 26)
  /// — отдельные `.ico` для Proxy/TUN, поставленные пользователем
  /// (`assets/tray_icon_proxy.ico`/`tray_icon_tun.ico`), тот же
  /// мульти-резолюшн набор размеров, что и у дефолтной `tray_icon.ico`.
  ///
  /// macOS-версия `tray_manager` не умеет `.ico` — ей нужен растровый
  /// `.png` под размер строки меню (см. `assets/tray_icon*_macos.png`,
  /// сконвертированы из тех же `.ico`).
  Future<void> _updateIcon() async {
    final state = container.read(connectionControllerProvider);
    final connected = state is ConnectionConnected;
    final path = switch (state) {
      ConnectionConnected(mode: ConnectionMode.proxy) =>
        Platform.isMacOS
            ? 'assets/tray_icon_proxy_macos.png'
            : 'assets/tray_icon_proxy.ico',
      ConnectionConnected(mode: ConnectionMode.tun) =>
        Platform.isMacOS
            ? 'assets/tray_icon_tun_macos.png'
            : 'assets/tray_icon_tun.ico',
      _ =>
        Platform.isMacOS
            ? 'assets/tray_icon_macos.png'
            : 'assets/tray_icon.ico',
    };
    // Off-иконка на macOS — однотонный контур без цвета, поэтому рисуем её
    // как template image: система сама красит её под текущую (свето-
    // /тёмную) тему меню-бара по альфа-каналу, вместо фиксированного серого,
    // который на светлой теме сливался с фоном. Proxy/TUN-иконки цветные
    // (статус-индикация), их шаблоном не делаем — так и было раньше.
    await trayManager.setIcon(path, isTemplate: Platform.isMacOS && !connected);
  }

  Future<void> _updateMenu() async {
    final state = container.read(connectionControllerProvider);
    final connected = state is ConnectionConnected;

    // Информационные строки (имя сервера/режим/статус) — только когда есть
    // что показать, не плодим пустые пункты в состоянии Off. `disabled`
    // делает их некликабельными — это подпись, не действие.
    final infoItems = switch (state) {
      ConnectionConnected(:final serverName, :final mode) => [
        MenuItem(key: 'info-server', label: serverName, disabled: true),
        MenuItem(
          key: 'info-mode',
          label: mode == ConnectionMode.tun ? 'TUN' : S.throughProxy,
          disabled: true,
        ),
        MenuItem(
          key: 'info-status',
          label: S.trayStatusConnected,
          disabled: true,
        ),
        MenuItem.separator(),
      ],
      ConnectionConnecting() => [
        MenuItem(
          key: 'info-status',
          label: S.trayStatusConnecting,
          disabled: true,
        ),
        MenuItem.separator(),
      ],
      _ => const <MenuItem>[],
    };

    await trayManager.setContextMenu(
      Menu(
        items: [
          ...infoItems,
          MenuItem(key: 'show', label: S.trayOpen),
          MenuItem(
            key: 'toggle',
            label: connected ? S.trayDisconnect : S.trayConnect,
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: S.trayExit),
        ],
      ),
    );
  }

  // bringAppToFront: true — иначе Windows не делает наше окно foreground
  // перед TrackPopupMenu (нативная реализация меню в tray_manager), а без
  // этого сам Win32 не закрывает popup-меню по клику вне его — оно виснет,
  // пока не выбран пункт. См. tray_manager_plugin.cpp: SetForegroundWindow
  // вызывается только при bringAppToFront == true. Параметр помечен
  // deprecated в пакете (обещают убрать в будущем — Windows-only), но замены
  // пока нет, а без него баг возвращается — используем осознанно.
  @override
  void onTrayIconMouseDown() =>
      // ignore: deprecated_member_use
      trayManager.popUpContextMenu(bringAppToFront: true);

  @override
  void onTrayIconRightMouseDown() =>
      // ignore: deprecated_member_use
      trayManager.popUpContextMenu(bringAppToFront: true);

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'toggle':
        await _toggleConnection();
      case 'exit':
        await windowManager.setPreventClose(false);
        await windowManager.close();
    }
  }

  Future<void> _toggleConnection() async {
    final controller = container.read(connectionControllerProvider.notifier);
    final state = container.read(connectionControllerProvider);
    if (state is ConnectionConnected) {
      await controller.disconnect();
      return;
    }

    final leaves = flattenAllLeaves(container.read(coreConfigProvider));
    final selectedId =
        container.read(selectedServerIdProvider) ??
        (leaves.isNotEmpty ? leaves.first.id : null);
    final leaf = leaves.where((l) => l.id == selectedId).firstOrNull;
    if (leaf == null) return;
    await controller.connectToServer(leaf);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
