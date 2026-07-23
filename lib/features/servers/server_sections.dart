import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/proxy_node.dart';
import 'flatten_leaves.dart';

/// Секция списка серверов — заголовок (имя подписки/группы, `null` для
/// серверов без подписки) и её серверы. Список пока не рекурсивный —
/// вложенные группы внутри подписки/standalone-группы тоже расплющиваются.
class ServerSection {
  final String? title;
  final List<ServerLeaf> leaves;

  const ServerSection({this.title, required this.leaves});
}

List<ServerSection> buildServerSections(CoreConfig config) {
  final sections = <ServerSection>[];

  final ungrouped = <ServerLeaf>[];
  for (final node in config.standaloneNodes) {
    switch (node) {
      case ServerLeaf leaf:
        ungrouped.add(leaf);
      case ServerGroup group:
        sections.add(
          ServerSection(title: group.name, leaves: flattenLeaves(group.children)),
        );
    }
  }
  if (ungrouped.isNotEmpty) {
    sections.insert(0, ServerSection(leaves: ungrouped));
  }

  for (final subscription in config.subscriptions) {
    sections.add(
      ServerSection(
        title: subscription.name,
        leaves: flattenLeaves([subscription.root]),
      ),
    );
  }

  return sections;
}
