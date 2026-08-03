import 'dart:io';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/dialog_style.dart';
import '../../app/layout_breakpoints.dart';
import '../../l10n/strings.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/xray/windows_elevation.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../servers/flatten_leaves.dart';
import '../servers/selected_server_provider.dart';
import '../servers/server_list_panel.dart';
import 'connection_controller.dart';
import 'connection_state.dart';
import 'home_tiles/home_tile_grid.dart';
import 'off_proxy_tun_selector.dart';

class ConnectPanel extends ConsumerStatefulWidget {
  const ConnectPanel({super.key});

  @override
  ConsumerState<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends ConsumerState<ConnectPanel> {
  @override
  Widget build(BuildContext context) {
    final leaves = flattenAllLeaves(ref.watch(coreConfigProvider));
    final selectedId =
        ref.watch(selectedServerIdProvider) ??
        (leaves.isNotEmpty ? leaves.first.id : null);
    final selectedLeaf = selectedId == null
        ? null
        : leaves.where((l) => l.id == selectedId).firstOrNull;
    final connectionState = ref.watch(connectionControllerProvider);
    final busy =
        connectionState is ConnectionConnecting ||
        connectionState is ConnectionStopping;

    if (selectedLeaf == null) {
      return Center(child: Text(S.selectServerHint, style: PortText.muted));
    }

    final grid = HomeTileGrid(
      leaf: selectedLeaf,
      connectionState: connectionState,
      busy: busy,
      onModeChanged: (selection) =>
          _onSelectionChanged(context, ref, selectedLeaf, selection),
      // Боковая панель со списком серверов скрыта на мобильной раскладке
      // (см. ROADMAP.md, трек 16) — тап по плитке сервера открывает тот же
      // bottom sheet, что и плавающая кнопка сверху, чтобы сменить сервер
      // было можно и отсюда. На десктопе список всегда виден сбоку.
      onOpenServerList:
          isMobileLayout(context) ? () => openServerListSheet(context) : null,
    );

    final content = Platform.isAndroid
        ? grid
        : ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: grid);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: content,
      ),
    );
  }

  Future<void> _onSelectionChanged(
    BuildContext context,
    WidgetRef ref,
    ServerLeaf leaf,
    ConnectSelection selection,
  ) async {
    final controller = ref.read(connectionControllerProvider.notifier);

    // Тактильный отклик на главное действие приложения — только Android,
    // desktop не трогаем (нет аналога вибрации на нажатие кнопки мышью).
    if (Platform.isAndroid) HapticFeedback.lightImpact();

    // Android: селектор уже схлопнут до Off/On (OffProxyTunSelector,
    // simplifiedOnOff), и isRunningElevated()/windows_elevation.dart —
    // Windows-only FFI (DynamicLibrary.open('shell32.dll')), падает на
    // Android при первом вызове. Единственный реальный механизм там — TUN
    // через VpnService (см. xray_engine_android.dart), поэтому режим всегда
    // ConnectionMode.tun — это ещё и то, что реально отражает архитектуру
    // (запрет пинга во время TUN и т.п. читают именно .mode).
    if (Platform.isAndroid) {
      switch (selection) {
        case ConnectSelection.off:
          await controller.disconnect();
        case ConnectSelection.proxy:
        case ConnectSelection.tun:
          await controller.connectToServer(leaf, mode: ConnectionMode.tun);
      }
      return;
    }

    switch (selection) {
      case ConnectSelection.off:
        await controller.disconnect();
      case ConnectSelection.proxy:
        await controller.connectToServer(leaf, mode: ConnectionMode.proxy);
      case ConnectSelection.tun:
        // isRunningElevated() — Windows-only FFI (shell32.dll, см.
        // windows_elevation.dart), падает при вызове на macOS так же, как
        // и на Android (см. комментарий выше). На macOS TUN через
        // NetworkExtension/System Extension (TunBridgeEngineMacOSNe) вообще
        // не требует root/элевейта — есть системный запрос на активацию
        // расширения (см. NetworkExtensionBridge.swift), но не Windows-style
        // UAC-релонч всего приложения.
        if (Platform.isMacOS || isRunningElevated()) {
          await controller.connectToServer(leaf, mode: ConnectionMode.tun);
          return;
        }
        if (!context.mounted) return;
        await _promptElevateForTun(context, ref);
    }
  }

  Future<void> _promptElevateForTun(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPortDialog<bool>(
      context: context,
      barrierColor: dialogBarrierColor,
      builder: (context) => PortDialog.alert(
        title: Text(S.adminRightsNeededTitle),
        description: Text(S.adminRightsNeededDescription),
        actions: [
          PortButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancel),
          ),
          PortButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.restart),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Гасим текущее подключение (снимает системный прокси и т.п.) перед
    // перезапуском — иначе пока стартует повышенная копия, старая остаётся
    // подключённой в фоне до убийства через Job Object.
    await ref.read(connectionControllerProvider.notifier).disconnect();

    final launched = relaunchElevated();
    if (launched) {
      // Без этого close() перехватывается WindowListener.onWindowClose
      // (см. main.dart, setPreventClose(true) для сворачивания в трей) и
      // просто прячет окно вместо выхода — старый неповышенный процесс
      // остаётся жить в трее и держит лок единственного инстанса, из-за
      // чего новая elevated-копия тут же завершается как "вторичный
      // инстанс" (см. single_instance.dart), а из трея открывается снова
      // тот же неповышенный процесс — TUN опять просит права.
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
