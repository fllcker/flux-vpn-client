import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/proxy_node.dart';

/// Плоский список серверов из дерева групп — экран пока показывает список
/// без вложенности (см. PLAN.md, "Иерархическая группировка серверов", как
/// будущее развитие UI).
List<ServerLeaf> flattenLeaves(List<ProxyNode> nodes) {
  final result = <ServerLeaf>[];
  for (final node in nodes) {
    switch (node) {
      case ServerLeaf leaf:
        result.add(leaf);
      case AutoSelectMarker():
        break;
      case ServerGroup group:
        result.addAll(flattenLeaves(group.children));
    }
  }
  return result;
}

/// Серверы и из отдельных узлов, и из деревьев всех подписок — единый
/// плоский список для UI.
List<ServerLeaf> flattenAllLeaves(CoreConfig config) {
  return [
    ...flattenLeaves(config.standaloneNodes),
    for (final subscription in config.subscriptions)
      ...flattenLeaves([subscription.root]),
  ];
}
