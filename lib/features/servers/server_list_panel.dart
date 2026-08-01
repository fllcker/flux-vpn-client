import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/layout_breakpoints.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../connection/connection_controller.dart';
import '../connection/connection_state.dart';
import '../ping/ping_all.dart';
import '../ping/ping_cache.dart';
import '../ping/pick_best_by_latency.dart';
import 'filter_hidden_nodes.dart';
import 'flatten_leaves.dart';
import 'import_subscription_sheet.dart';
import 'proxy_tree_list.dart';
import 'selected_server_provider.dart';
import 'subscription_info_panel.dart';

/// Открывает список серверов выезжающим снизу листом — мобильная раскладка
/// (см. ROADMAP.md, трек 16), вызывается и плавающей кнопкой в
/// `connection_screen.dart`, и тапом по карточке выбранного сервера в
/// `connect_panel.dart`, когда боковая панель скрыта.
Future<void> openServerListSheet(BuildContext context) {
  return showPortBottomSheet<void>(
    context: context,
    builder: (sheetContext) => ServerListContent(
      onAfterSelect: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// Список серверов в постоянной боковой колонке — десктопная раскладка
/// (`connection_screen.dart`). На узких окнах (см. ROADMAP.md, трек 16) тот
/// же список показывается через [showServerListBottomSheet] вместо этой
/// колонки — вся реальная логика вынесена в [ServerListContent], этот виджет
/// лишь оборачивает её в боковую панель фиксированной ширины.
class ServerListPanel extends StatelessWidget {
  const ServerListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: PortColors.border)),
      ),
      child: const ServerListContent(),
    );
  }
}

/// Содержимое списка серверов без внешней рамки/фиксированной ширины —
/// переиспользуется и боковой панелью ([ServerListPanel]), и выезжающим
/// снизу листом на мобильной раскладке ([showServerListBottomSheet]).
class ServerListContent extends ConsumerWidget {
  /// Вызывается сразу после выбора сервера/варианта — на bottom sheet это
  /// закрывает лист, в боковой панели не передаётся (`null` — no-op).
  final VoidCallback? onAfterSelect;

  const ServerListContent({super.key, this.onAfterSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(coreConfigProvider);
    final allLeaves = flattenAllLeaves(config);
    final selectedId =
        ref.watch(selectedServerIdProvider) ??
        (allLeaves.isNotEmpty ? allLeaves.first.id : null);
    // Переподключаемся к [leafId] с обновлённым конфигом, если во время
    // активного соединения пользователь выбрал другой сервер или другой
    // вариант подключения у текущего — тем же режимом (Proxy/TUN). Раньше
    // выбор только обновлял состояние UI ("какой сервер выделен"), а движок
    // продолжал жить со старым конфигом, пока пользователь вручную не
    // дёргал выключение/включение — выглядело так, будто смена
    // сервера/варианта вообще ни на что не влияет.
    void reconnectToLeafIfActive(String leafId) {
      final connectionState = ref.read(connectionControllerProvider);
      if (connectionState is! ConnectionConnected) return;
      final updatedLeaf = flattenAllLeaves(ref.read(coreConfigProvider))
          .where((l) => l.id == leafId)
          .firstOrNull;
      if (updatedLeaf != null) {
        ref
            .read(connectionControllerProvider.notifier)
            .connectToServer(updatedLeaf, mode: connectionState.mode);
      }
    }

    void onSelectLeaf(String id) {
      ref.read(selectedServerIdProvider.notifier).select(id);
      onAfterSelect?.call();
      reconnectToLeafIfActive(id);
    }

    void onSelectVariant(String leafId, String variantId) {
      ref.read(coreConfigProvider.notifier).selectVariant(leafId, variantId);
      ref.read(selectedServerIdProvider.notifier).select(leafId);
      onAfterSelect?.call();
      reconnectToLeafIfActive(leafId);
    }

    void onHideLeaf(String leafId) {
      ref.read(coreConfigProvider.notifier).setHidden(leafId, true);
    }

    // Информация о подписке — всегда всплывающая поверх главного экрана, не
    // встроенная в постоянную колонку/список (раньше подменяла ConnectPanel
    // через rightPanelViewProvider — на обеих раскладках не было явного
    // "назад", кроме случайного клика по серверу, см. чат). Мобилка: тот же
    // bottom sheet, что и список серверов — закрываем текущий (со списком) и
    // тут же открываем новый (с инфой), а не складываем два друг на друга.
    // Десктоп: модалка (showSubscriptionInfoDialog), список слева остаётся
    // как был, ничего не подменяется.
    void onOpenSubscriptionInfo(String subscriptionId) {
      if (isMobileLayout(context)) {
        // pop() не отключает context синхронно (снятие route идёт через
        // анимацию отдельным кадром) — тот же context ещё валиден для
        // немедленного показа второго листа сразу следом, без
        // промежуточного "провала" на голый ConnectPanel между ними.
        Navigator.of(context).pop();
        showPortBottomSheet<void>(
          context: context,
          builder: (_) => SubscriptionInfoPanel(subscriptionId: subscriptionId),
        );
        return;
      }
      showSubscriptionInfoDialog(context, subscriptionId: subscriptionId);
    }

    final pingCache = ref.watch(pingCacheProvider);
    final pingingLeafIds = ref.watch(pingingLeafIdsProvider);

    void showTunPingBlockedToast() {
      PortToaster.of(context).show(
        PortToast(
          title: Text(S.cannotPingInTun),
          description: Text(S.pingBlocksTunDescription),
        ),
      );
    }

    void onPingLeaf(String leafId) {
      if (isTunActive(ref)) {
        showTunPingBlockedToast();
        return;
      }
      final leaf = allLeaves.where((l) => l.id == leafId).firstOrNull;
      if (leaf != null) pingLeaf(ref, leaf);
    }

    void onPingAll() {
      if (isTunActive(ref)) {
        showTunPingBlockedToast();
        return;
      }
      pingAllLeaves(ref, allLeaves);
    }

    void onReorder(String draggedId, String targetParentGroupId, int targetIndex) {
      ref
          .read(coreConfigProvider.notifier)
          .moveNode(draggedId, targetParentGroupId, targetIndex);
    }

    // V1 — разовый выбор (не live failover): берём лучший по свежему кэшу
    // пинга, иначе — первый по списку и фоновый пинг группы на будущее. См.
    // ROADMAP.md, трек 5.
    void onSelectAuto(String groupId, List<ServerLeaf> leavesInGroup) {
      if (leavesInGroup.isEmpty) return;
      final bestId =
          pickBestByLatency(leavesInGroup, pingCache) ?? leavesInGroup.first.id;
      onSelectLeaf(bestId);
      ref.read(coreConfigProvider.notifier).markGroupAutoSelected(groupId);
      if (pickBestByLatency(leavesInGroup, pingCache) == null) {
        pingAllLeaves(ref, leavesInGroup);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 12),
            child: Row(
              children: [
                Expanded(child: Text(S.servers, style: PortText.h4)),
                if (allLeaves.isNotEmpty)
                  PortIconButton.ghost(
                    icon: const Icon(LucideIcons.activity, size: 16),
                    onPressed: pingingLeafIds.isEmpty ? onPingAll : null,
                  ),
                PortIconButton.ghost(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => showAddServerDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: allLeaves.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      S.noServersYet,
                      style: PortText.muted,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      if (config.standaloneNodes.isNotEmpty)
                        ProxyTreeList(
                          nodes: config.standaloneNodes,
                          selectedLeafId: selectedId,
                          onSelectLeaf: onSelectLeaf,
                          onSelectVariant: onSelectVariant,
                          onPingLeaf: onPingLeaf,
                          latencyForLeaf: (id) => pingCache[id]?.latencyMs,
                          pingingLeafIds: pingingLeafIds,
                          parentGroupId: standaloneParentId,
                          onReorder: onReorder,
                        ),
                      for (final subscription in config.subscriptions) ...[
                        _SubscriptionHeader(
                          title: subscription.name,
                          onTap: () => onOpenSubscriptionInfo(subscription.id),
                        ),
                        ProxyTreeList(
                          nodes: filterHiddenList(switch (subscription.root) {
                            ServerGroup(:final children) => children,
                            final leaf => [leaf],
                          }),
                          selectedLeafId: selectedId,
                          onSelectLeaf: onSelectLeaf,
                          onSelectVariant: onSelectVariant,
                          onHideLeaf: onHideLeaf,
                          onPingLeaf: onPingLeaf,
                          latencyForLeaf: (id) => pingCache[id]?.latencyMs,
                          pingingLeafIds: pingingLeafIds,
                          parentGroupId: subscription.root.id,
                          onSelectAuto: onSelectAuto,
                          onReorder: onReorder,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionHeader extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _SubscriptionHeader({
    required this.title,
    required this.onTap,
  });

  @override
  State<_SubscriptionHeader> createState() => _SubscriptionHeaderState();
}

class _SubscriptionHeaderState extends State<_SubscriptionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: highlighted ? PortColors.accent : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: PortText.muted.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: highlighted ? PortColors.foreground : null,
                  ),
                ),
              ),
              Icon(
                LucideIcons.info,
                size: 12,
                color: PortColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
