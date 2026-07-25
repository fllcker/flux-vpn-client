import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/dialog_style.dart';
import '../../app/layout_breakpoints.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/xray/windows_elevation.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../servers/flatten_leaves.dart';
import '../servers/selected_server_provider.dart';
import '../servers/server_icon.dart';
import '../servers/server_list_panel.dart';
import 'connection_controller.dart';
import 'connection_state.dart';
import 'connection_timer.dart';
import 'off_proxy_tun_selector.dart';

class ConnectPanel extends ConsumerStatefulWidget {
  const ConnectPanel({super.key});

  @override
  ConsumerState<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends ConsumerState<ConnectPanel> {
  // IntrinsicWidth недостаточно точен для Row из AnimatedContainer
  // (см. историю переполнения) — вместо приближённого intrinsic-расчёта
  // измеряем реальную отрисованную ширину переключателя после кадра и
  // задаём её карточке сервера явно, чтобы совпадение было пиксельным.
  final _selectorKey = GlobalKey();
  double? _selectorWidth;

  void _measureSelectorWidth(Duration _) {
    final width = _selectorKey.currentContext?.size?.width;
    if (width != null && width != _selectorWidth) {
      setState(() => _selectorWidth = width);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measureSelectorWidth);
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
      return Center(
        child: Text(
          'Выберите сервер слева, чтобы подключиться.',
          style: PortText.muted,
        ),
      );
    }

    final selection = switch (connectionState) {
      ConnectionConnected(mode: ConnectionMode.proxy) => ConnectSelection.proxy,
      ConnectionConnected(mode: ConnectionMode.tun) => ConnectSelection.tun,
      _ => ConnectSelection.off,
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _selectorWidth,
                child: GestureDetector(
                  // Боковая панель со списком серверов скрыта на мобильной
                  // раскладке (см. ROADMAP.md, трек 16) — тап по карточке
                  // открывает тот же bottom sheet, что и плавающая кнопка
                  // сверху, чтобы сменить сервер было можно и отсюда.
                  onTap: isMobileLayout(context)
                      ? () => openServerListSheet(context)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: PortColors.muted.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ServerIcon(icon: selectedLeaf.icon, size: 32),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedLeaf.name,
                                style: PortText.large.copyWith(height: 1),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              _StatusText(state: connectionState),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OffProxyTunSelector(
                key: _selectorKey,
                value: selection,
                busy: busy,
                onChanged: (selection) => _onSelectionChanged(
                  context,
                  ref,
                  selectedLeaf,
                  selection,
                ),
              ),
            ],
          ),
        ),
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
    switch (selection) {
      case ConnectSelection.off:
        await controller.disconnect();
      case ConnectSelection.proxy:
        await controller.connectToServer(leaf, mode: ConnectionMode.proxy);
      case ConnectSelection.tun:
        if (isRunningElevated()) {
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
        title: const Text('Нужны права администратора'),
        description: const Text(
          'Режим TUN требует прав администратора. Перезапустить '
          'приложение с повышенными правами?',
        ),
        actions: [
          PortButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          PortButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Перезапустить'),
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
    return Text(text, style: PortText.muted.copyWith(height: 1));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
