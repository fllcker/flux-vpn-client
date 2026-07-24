import 'package:uuid/uuid.dart';

import '../../core_abstraction/proxy_node.dart';

const _uuid = Uuid();

/// Вставляет узел [AutoSelectMarker] первым элементом в каждую [ServerGroup]
/// дерева (рекурсивно, включая вложенные группы) — вызывается один раз при
/// конвертации стороннего конфига (импорт/рефреш подписки), после
/// `group_leaves_by_name.dart`, см. ROADMAP.md, трек 5. [ServerLeaf] и уже
/// существующий [AutoSelectMarker] возвращаются как есть.
ProxyNode insertAutoSelectMarkers(ProxyNode node) {
  return switch (node) {
    ServerLeaf leaf => leaf,
    AutoSelectMarker marker => marker,
    ServerGroup group => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.strategy,
      children: [
        AutoSelectMarker(id: _uuid.v4()),
        for (final child in group.children) insertAutoSelectMarkers(child),
      ],
    ),
  };
}
