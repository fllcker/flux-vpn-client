import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core_abstraction/core_config_provider.dart';
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
    if (!Platform.isWindows) return;

    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Flux');
    await _updateMenu();

    container.listen(connectionControllerProvider, (_, _) => _updateMenu());
  }

  Future<void> _updateMenu() async {
    final connected = container.read(connectionControllerProvider)
        is ConnectionConnected;

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Открыть'),
          MenuItem(key: 'toggle', label: connected ? 'Отключить' : 'Подключить'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Выход'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

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
