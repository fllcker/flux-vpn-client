import '../../core_abstraction/proxy_node.dart';

/// Возвращает [node] без скрытых листьев, либо `null`, если сам лист скрыт
/// или группа опустела после рекурсивной фильтрации детей (пустая группа
/// бесполезна и путает — см. ROADMAP.md, трек 2). Применяется к дереву
/// подписки перед рендером основного списка серверов; скрытые серверы
/// показываются отдельно на странице подписки (см. `subscription_info_panel.dart`).
ProxyNode? filterHidden(ProxyNode node) {
  return switch (node) {
    ServerLeaf leaf => leaf.hidden ? null : leaf,
    ServerGroup group => _filterGroup(group),
  };
}

ServerGroup? _filterGroup(ServerGroup group) {
  if (group.hidden) return null;
  final children = group.children
      .map(filterHidden)
      .whereType<ProxyNode>()
      .toList();
  if (children.isEmpty) return null;
  return ServerGroup(
    id: group.id,
    name: group.name,
    icon: group.icon,
    hidden: group.hidden,
    strategy: group.strategy,
    children: children,
  );
}

/// То же самое для списка детей верхнего уровня (`ServerGroup.children`,
/// `Subscription.root` уже развёрнутый) — удобнее вызывать напрямую в
/// местах, где список используется без обёртки-группы.
List<ProxyNode> filterHiddenList(List<ProxyNode> nodes) =>
    nodes.map(filterHidden).whereType<ProxyNode>().toList();
