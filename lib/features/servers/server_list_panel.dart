import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../widgets/port_ui/port_ui.dart';
import '../ping/ping_all.dart';
import '../ping/ping_cache.dart';
import '../ping/pick_best_by_latency.dart';
import 'filter_hidden_nodes.dart';
import 'flatten_leaves.dart';
import 'import_subscription_sheet.dart';
import 'proxy_tree_list.dart';
import 'right_panel_view.dart';
import 'routing_rules_dialog.dart';
import 'selected_server_provider.dart';

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
      decoration: const BoxDecoration(
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
    final rightPanelView = ref.watch(rightPanelViewProvider);
    final activeSubscriptionId = switch (rightPanelView) {
      SubscriptionInfoView(:final subscriptionId) => subscriptionId,
      ConnectView() => null,
    };

    void onSelectLeaf(String id) {
      ref.read(selectedServerIdProvider.notifier).select(id);
      ref.read(rightPanelViewProvider.notifier).showConnect();
      onAfterSelect?.call();
    }

    void onSelectVariant(String leafId, String variantId) {
      ref.read(coreConfigProvider.notifier).selectVariant(leafId, variantId);
      ref.read(selectedServerIdProvider.notifier).select(leafId);
      ref.read(rightPanelViewProvider.notifier).showConnect();
      onAfterSelect?.call();
    }

    void onHideLeaf(String leafId) {
      ref.read(coreConfigProvider.notifier).setHidden(leafId, true);
    }

    void onEditRoutingLeaf(String leafId) {
      final leaf = allLeaves.where((l) => l.id == leafId).firstOrNull;
      if (leaf == null) return;
      showRoutingRulesDialog(
        context,
        title: 'Роутинг — ${leaf.name}',
        initialRules: leaf.routingRules,
        onSave: (rules) =>
            ref.read(coreConfigProvider.notifier).setRoutingRules(leafId, rules),
      );
    }

    final pingCache = ref.watch(pingCacheProvider);
    final pingingLeafIds = ref.watch(pingingLeafIdsProvider);

    void showTunPingBlockedToast() {
      PortToaster.of(context).show(
        const PortToast(
          title: Text('Нельзя пинговать в TUN-режиме'),
          description: Text(
            'Измерение задержки мешает активному TUN-соединению — '
            'отключитесь или переключитесь на Proxy, чтобы пинговать.',
          ),
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
                Expanded(child: Text('Серверы', style: PortText.h4)),
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
                      'Пока нет серверов — добавьте подписку или ссылку.',
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
                          onEditRoutingLeaf: onEditRoutingLeaf,
                          onPingLeaf: onPingLeaf,
                          latencyForLeaf: (id) => pingCache[id]?.latencyMs,
                          pingingLeafIds: pingingLeafIds,
                          parentGroupId: standaloneParentId,
                          onReorder: onReorder,
                        ),
                      for (final subscription in config.subscriptions) ...[
                        _SubscriptionHeader(
                          title: subscription.name,
                          active: subscription.id == activeSubscriptionId,
                          onTap: () => ref
                              .read(rightPanelViewProvider.notifier)
                              .showSubscription(subscription.id),
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
                          onEditRoutingLeaf: onEditRoutingLeaf,
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
  final bool active;
  final VoidCallback onTap;

  const _SubscriptionHeader({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SubscriptionHeader> createState() => _SubscriptionHeaderState();
}

class _SubscriptionHeaderState extends State<_SubscriptionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;

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
                    color: widget.active ? PortColors.foreground : null,
                  ),
                ),
              ),
              const Icon(
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
