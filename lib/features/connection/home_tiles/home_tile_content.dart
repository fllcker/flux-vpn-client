import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core_abstraction/connection_session.dart';
import '../../../core_abstraction/home_tile_config.dart';
import '../../../core_abstraction/proxy_node.dart';
import '../../../l10n/strings.dart';
import '../../../widgets/port_ui/port_ui.dart';
import '../../servers/server_icon.dart';
import '../connection_state.dart';
import '../connection_timer.dart';
import '../off_proxy_tun_selector.dart';

/// Диспетчер ВИЗУАЛЬНОГО содержимого плитки по [HomeTileConfig.type] —
/// используется `HomeTileGrid` внутри `HomeTileCard`. Чисто презентационный,
/// без Riverpod и без обработки тапа: для `routingPreset`/`variantSelector`
/// (которым нужны провайдеры и открытие меню по месту тапа) это отдельно
/// решает сам `home_tile_grid.dart` (`_buildTile`), передавая сюда только
/// уже готовые для отображения данные — держим один источник данных
/// (`_HomeTileGridState`, уже читает нужные провайдеры для раскладки) вместо
/// того, чтобы плитки читали их повторно сами по себе.
Widget buildHomeTileContent(
  HomeTileConfig tile, {
  required ServerLeaf? leaf,
  required ConnectionUiState connectionState,
  required bool busy,
  required ValueChanged<ConnectSelection> onModeChanged,
  required String routingPresetLabel,
  required String variantLabel,
  required bool variantEnabled,
}) {
  final modeSelection = switch (connectionState) {
    ConnectionConnected(mode: ConnectionMode.proxy) => ConnectSelection.proxy,
    ConnectionConnected(mode: ConnectionMode.tun) => ConnectSelection.tun,
    _ => ConnectSelection.off,
  };

  return switch (tile.type) {
    HomeTileType.serverInfo => _ServerInfoContent(leaf: leaf, connectionState: connectionState, size: tile.size),
    HomeTileType.serverIcon => _ServerIconContent(leaf: leaf),
    HomeTileType.serverStatus => _ServerStatusContent(leaf: leaf, connectionState: connectionState),
    // `small` — тап открывает меню Off/Proxy/TUN вместо встроенных
    // сегментов (не помещаются в 1/3 ширины), см. `home_tile_grid.dart`
    // `_openModeMenu`.
    HomeTileType.modeSelector when tile.size == HomeTileSize.small =>
      _ModeSelectorCompact(selection: modeSelection, simplifiedOnOff: Platform.isAndroid),
    HomeTileType.modeSelector => OffProxyTunSelector(
        value: modeSelection,
        busy: busy,
        radiusStyle: tile.radiusStyle,
        simplifiedOnOff: Platform.isAndroid,
        onChanged: onModeChanged,
      ),
    HomeTileType.routingPreset =>
      PickerTileVisual(icon: LucideIcons.map, label: routingPresetLabel, size: tile.size),
    HomeTileType.variantSelector => Opacity(
        opacity: variantEnabled ? 1 : 0.5,
        child: PickerTileVisual(icon: LucideIcons.network, label: variantLabel, size: tile.size),
      ),
  };
}

/// Компактный вид `modeSelector` для `small` (1/3 ширины) — просто текущий
/// режим текстом, тот же цвет, что и у выбранного сегмента
/// `OffProxyTunSelector`.
class _ModeSelectorCompact extends StatelessWidget {
  final ConnectSelection selection;
  final bool simplifiedOnOff;
  const _ModeSelectorCompact({required this.selection, required this.simplifiedOnOff});

  @override
  Widget build(BuildContext context) {
    final label = switch (selection) {
      ConnectSelection.off => 'Off',
      ConnectSelection.proxy => 'Proxy',
      ConnectSelection.tun => simplifiedOnOff ? 'On' : 'TUN',
    };
    final color = switch (selection) {
      ConnectSelection.off => PortColors.mutedForeground,
      ConnectSelection.proxy => const Color(0xFF4ADE80),
      ConnectSelection.tun => simplifiedOnOff ? const Color(0xFF4ADE80) : const Color(0xFF60A5FA),
    };
    return Text(label, style: PortText.small.copyWith(color: color, fontWeight: FontWeight.w600));
  }
}

/// Совмещённая иконка+имя+статус — вид "как раньше" (см. `connect_panel.dart`
/// до реворка на плитки). `small` — компактный вариант (только иконка+имя,
/// без строки статуса) для 1/3 ширины, чтобы рядом помещалась ещё плитка.
class _ServerInfoContent extends StatelessWidget {
  final ServerLeaf? leaf;
  final ConnectionUiState connectionState;
  final HomeTileSize size;

  const _ServerInfoContent({required this.leaf, required this.connectionState, required this.size});

  @override
  Widget build(BuildContext context) {
    final leaf = this.leaf;
    if (leaf == null) {
      return Text(S.selectServerHint, style: PortText.muted, textAlign: TextAlign.center);
    }

    if (size == HomeTileSize.small) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ServerIcon(icon: leaf.icon, size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(leaf.name, style: PortText.small, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ServerIcon(icon: leaf.icon, size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                leaf.name,
                style: PortText.small.copyWith(fontSize: 14, height: 1),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              StatusText(state: connectionState),
            ],
          ),
        ),
      ],
    );
  }
}

/// Только иконка сервера — часть разбитой на несколько плиток `serverInfo`.
class _ServerIconContent extends StatelessWidget {
  final ServerLeaf? leaf;
  const _ServerIconContent({required this.leaf});

  @override
  Widget build(BuildContext context) {
    final leaf = this.leaf;
    if (leaf == null) return const SizedBox.shrink();
    return ServerIcon(icon: leaf.icon, size: 24);
  }
}

/// Только имя+статус/таймер — часть разбитой на несколько плиток `serverInfo`.
class _ServerStatusContent extends StatelessWidget {
  final ServerLeaf? leaf;
  final ConnectionUiState connectionState;
  const _ServerStatusContent({required this.leaf, required this.connectionState});

  @override
  Widget build(BuildContext context) {
    final leaf = this.leaf;
    if (leaf == null) {
      return Text(S.selectServerHint, style: PortText.muted, textAlign: TextAlign.center);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          leaf.name,
          style: PortText.small.copyWith(fontSize: 14, height: 1),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        StatusText(state: connectionState),
      ],
    );
  }
}

/// Статус подключения — секундомер, если подключено, иначе локализованный
/// текст. Вынесен из `connect_panel.dart`, переиспользуется `serverInfo` и
/// `serverStatus`.
class StatusText extends StatelessWidget {
  final ConnectionUiState state;
  const StatusText({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state case ConnectionConnected(connectedAt: final connectedAt)) {
      return ConnectionTimer(connectedAt: connectedAt);
    }

    final text = switch (state) {
      ConnectionIdle() => S.disconnected,
      ConnectionConnecting() => S.connectingStatus,
      ConnectionStopping() => S.disconnectingStatus,
      ConnectionError(message: final message) => S.connectionError(message),
      ConnectionConnected() => '', // обработано выше
    };
    return Text(text, style: PortText.muted.copyWith(height: 1));
  }
}

/// Общий вид для тап-открываемых плиток-переключателей (routingPreset,
/// variantSelector): иконка+подпись на `wide`/`large`, только иконка на
/// `small`. Чисто презентационный — тап обрабатывает `HomeTileCard` снаружи
/// (см. `home_tile_grid.dart`), сам виджет о меню/провайдерах не знает.
class PickerTileVisual extends StatelessWidget {
  final IconData icon;
  final String label;
  final HomeTileSize size;

  const PickerTileVisual({super.key, required this.icon, required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    if (size == HomeTileSize.small) {
      return Icon(icon, size: 18, color: PortColors.mutedForeground);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: PortColors.mutedForeground),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: PortText.small, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
