import '../../core_abstraction/proxy_node.dart';
import 'flatten_leaves.dart';
import 'group_leaves_by_name.dart';
import 'insert_auto_select_markers.dart';

/// Пересобирает порядок и группировку дерева подписки "по умолчанию" —
/// заново прогоняет текущие листья (id/hidden/routingRules/selection не
/// трогаются, меняется только их расположение) через `groupLeavesByName`,
/// откатывая любую ручную drag-and-drop сортировку (см. ROADMAP.md, трек 6)
/// к тому, что даёт автогруппировка по именам серверов. Не ходит в сеть — в
/// отличие от рефреша подписки, работает с уже загруженными данными.
ServerGroup rebuildDefaultOrder(ServerGroup root) {
  final leaves = flattenLeaves([root]);
  return insertAutoSelectMarkers(
    ServerGroup(
      id: root.id,
      name: root.name,
      icon: root.icon,
      hidden: root.hidden,
      children: groupLeavesByName(leaves),
    ),
  ) as ServerGroup;
}
