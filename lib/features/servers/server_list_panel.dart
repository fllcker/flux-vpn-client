import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import 'filter_hidden_nodes.dart';
import 'flatten_leaves.dart';
import 'import_subscription_sheet.dart';
import 'proxy_tree_list.dart';
import 'right_panel_view.dart';
import 'selected_server_provider.dart';

class ServerListPanel extends ConsumerWidget {
  const ServerListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
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
    }

    void onSelectVariant(String leafId, String variantId) {
      ref.read(coreConfigProvider.notifier).selectVariant(leafId, variantId);
      ref.read(selectedServerIdProvider.notifier).select(leafId);
      ref.read(rightPanelViewProvider.notifier).showConnect();
    }

    void onHideLeaf(String leafId) {
      ref.read(coreConfigProvider.notifier).setHidden(leafId, true);
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 12),
            child: Row(
              children: [
                Expanded(child: Text('Серверы', style: theme.textTheme.h4)),
                ShadIconButton.ghost(
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
                      style: theme.textTheme.muted,
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
    final theme = ShadTheme.of(context);
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
            color: highlighted ? theme.colorScheme.accent : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: widget.active ? theme.colorScheme.foreground : null,
                  ),
                ),
              ),
              Icon(
                LucideIcons.info,
                size: 12,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
