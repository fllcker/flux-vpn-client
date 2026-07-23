import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../servers/flatten_leaves.dart';
import '../servers/selected_server_provider.dart';
import '../servers/server_icon.dart';
import 'connection_controller.dart';
import 'connection_state.dart';
import 'connection_timer.dart';
import 'off_proxy_tun_selector.dart';

class ConnectPanel extends ConsumerWidget {
  const ConnectPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final leaves = flattenAllLeaves(ref.watch(coreConfigProvider));
    final selectedId =
        ref.watch(selectedServerIdProvider) ??
        (leaves.isNotEmpty ? leaves.first.id : null);
    final selectedLeaf = selectedId == null
        ? null
        : leaves.where((l) => l.id == selectedId).firstOrNull;
    final connectionState = ref.watch(connectionControllerProvider);
    final connected = connectionState is ConnectionConnected;
    final busy =
        connectionState is ConnectionConnecting ||
        connectionState is ConnectionStopping;

    if (selectedLeaf == null) {
      return Center(
        child: Text(
          'Выберите сервер слева, чтобы подключиться.',
          style: theme.textTheme.muted,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ServerIcon(icon: selectedLeaf.icon, size: 64),
            const SizedBox(height: 12),
            Text(selectedLeaf.name, style: theme.textTheme.h4),
            const SizedBox(height: 4),
            _StatusText(state: connectionState),
            const SizedBox(height: 24),
            OffProxyTunSelector(
              value: connected
                  ? ConnectSelection.proxy
                  : ConnectSelection.off,
              busy: busy,
              onChanged: (selection) {
                final controller = ref.read(
                  connectionControllerProvider.notifier,
                );
                switch (selection) {
                  case ConnectSelection.off:
                    controller.disconnect();
                  case ConnectSelection.proxy:
                    controller.connectToServer(selectedLeaf);
                  case ConnectSelection.tun:
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final ConnectionUiState state;
  const _StatusText({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state case ConnectionConnected(connectedAt: final connectedAt)) {
      return ConnectionTimer(connectedAt: connectedAt);
    }

    final text = switch (state) {
      ConnectionIdle() => 'Отключено',
      ConnectionConnecting() => 'Подключение...',
      ConnectionStopping() => 'Отключение...',
      ConnectionError(message: final message) => 'Ошибка: $message',
      ConnectionConnected() => '', // обработано выше
    };
    return Text(text, style: ShadTheme.of(context).textTheme.muted);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
