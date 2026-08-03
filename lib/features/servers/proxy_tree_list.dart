import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core_abstraction/core_config_provider.dart' show standaloneParentId;
import '../../core_abstraction/proxy_node.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'expanded_nodes_provider.dart';
import 'flatten_leaves.dart';
import 'server_icon.dart';
import 'server_row.dart';

/// Рекурсивный рендер дерева серверов/групп — инлайн-аккордеон: клик по
/// группе или по серверу с несколькими вариантами разворачивает детей
/// прямо под строкой (без поповеров/оверлеев, без ограничения по ширине
/// панели).
class ProxyTreeList extends ConsumerWidget {
  final List<ProxyNode> nodes;
  final int depth;
  final String? selectedLeafId;
  final ValueChanged<String> onSelectLeaf;
  final void Function(String leafId, String variantId) onSelectVariant;
  // Пункт "Скрыть" в контекстном меню строки — только для серверов внутри
  // подписки (standalone-серверы скрытие не поддерживают, см. ROADMAP.md,
  // трек 2).
  final ValueChanged<String>? onHideLeaf;
  // Пинг — доступен и standalone-серверам, и серверам внутри подписки (см.
  // ROADMAP.md, трек 4). onPingLeaf == null скрывает индикатор целиком.
  final ValueChanged<String>? onPingLeaf;
  final int? Function(String leafId)? latencyForLeaf;
  final Set<String> pingingLeafIds;
  // Id группы, чьи дети рендерит этот уровень рекурсии — нужен только для
  // клика по строке "Авто" (см. ROADMAP.md, трек 5): она находится среди
  // `nodes` этого же уровня, но сама группа-владелец недоступна отсюда без
  // явной передачи id.
  final String? parentGroupId;
  // Id всех групп-предков узлов этого уровня (от корня дерева до
  // [parentGroupId] включительно) — нужен только для drag-n-drop: без него
  // можно перетащить группу внутрь её же собственного потомка (в том числе
  // в её же собственный список детей или на его trailing-зону). Само
  // сохранение (`moveNodeInTree`, core_config_provider.dart) от такой
  // перестановки уже защищено порядком операций (извлекает узел из дерева
  // раньше, чем ищет целевую группу, так что self/потомок там просто не
  // найдётся) — но `DragTarget` без этой проверки всё равно ПОКАЗЫВАЕТ
  // приём дропа (подсветку), хотя по факту ничего не изменится, что
  // выглядит как баг с точки зрения жеста, а не только данных.
  final List<String> ancestorGroupIds;
  final void Function(String groupId, List<ServerLeaf> leavesInGroup)?
  onSelectAuto;
  // Драг-н-дрой сортировки (см. ROADMAP.md, трек 6): dragged node id, id
  // группы-цели (или `standaloneParentId`) и индекс внутри её `children`.
  // null отключает перетаскивание целиком (например, в диалогах, где дерево
  // рендерится вне основного списка серверов).
  final void Function(
    String draggedNodeId,
    String targetParentGroupId,
    int targetIndex,
  )?
  onReorder;

  const ProxyTreeList({
    super.key,
    required this.nodes,
    this.depth = 0,
    required this.selectedLeafId,
    required this.onSelectLeaf,
    required this.onSelectVariant,
    this.onHideLeaf,
    this.onPingLeaf,
    this.latencyForLeaf,
    this.pingingLeafIds = const {},
    this.parentGroupId,
    this.ancestorGroupIds = const [],
    this.onSelectAuto,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(expandedNodesProvider);
    final toggle = ref.read(expandedNodesProvider.notifier).toggle;
    // Родитель для операций "переставить перед этим узлом"/"добавить в
    // конец" на ЭТОМ уровне рекурсии — id группы-владельца `nodes`, либо
    // standalone-список, если владельца-группы нет вообще.
    final ownParentId = parentGroupId ?? standaloneParentId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in nodes)
          switch (node) {
            ServerGroup group => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragWrap(
                  nodeId: group.id,
                  feedbackLabel: group.name,
                  feedbackIcon: group.icon,
                  // Дроп на строку группы = переместить внутрь неё (в
                  // конец) — переставить группу саму на этом уровне можно,
                  // бросив её на соседний лист или в конец списка.
                  onAccept: (draggedId) =>
                      onReorder!(draggedId, group.id, group.children.length),
                  child: _GroupRow(
                    group: group,
                    depth: depth,
                    expanded: expanded.contains(group.id),
                    onTap: () => toggle(group.id),
                  ),
                ),
                if (expanded.contains(group.id))
                  ProxyTreeList(
                    nodes: group.children,
                    depth: depth + 1,
                    selectedLeafId: selectedLeafId,
                    onSelectLeaf: onSelectLeaf,
                    onSelectVariant: onSelectVariant,
                    onHideLeaf: onHideLeaf,
                    onPingLeaf: onPingLeaf,
                    latencyForLeaf: latencyForLeaf,
                    pingingLeafIds: pingingLeafIds,
                    parentGroupId: group.id,
                    ancestorGroupIds: [...ancestorGroupIds, group.id],
                    onSelectAuto: onSelectAuto,
                    onReorder: onReorder,
                  ),
              ],
            ),
            AutoSelectMarker marker => onSelectAuto == null || parentGroupId == null
                ? const SizedBox.shrink()
                : _AutoRow(
                    marker: marker,
                    depth: depth,
                    onTap: () => onSelectAuto!(
                      parentGroupId!,
                      flattenLeaves(nodes),
                    ),
                  ),
            ServerLeaf leaf => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dragWrap(
                    nodeId: leaf.id,
                    feedbackLabel: leaf.name,
                    feedbackIcon: leaf.icon,
                    // Дроп на строку сервера = встать перед ним на этом же
                    // уровне.
                    onAccept: (draggedId) => onReorder!(
                      draggedId,
                      ownParentId,
                      nodes.indexOf(leaf),
                    ),
                    child: ServerRow(
                      leaf: leaf,
                      depth: depth,
                      selected: leaf.id == selectedLeafId,
                      expanded: expanded.contains(leaf.id),
                      onSelect: () => onSelectLeaf(leaf.id),
                      onToggleExpand: () => toggle(leaf.id),
                      onHide: onHideLeaf == null
                          ? null
                          : () => onHideLeaf!(leaf.id),
                      latencyMs: latencyForLeaf?.call(leaf.id),
                      pinging: pingingLeafIds.contains(leaf.id),
                      onPing: onPingLeaf == null
                          ? null
                          : () => onPingLeaf!(leaf.id),
                    ),
                  ),
                  if (leaf.variants.length > 1 && expanded.contains(leaf.id))
                    for (final variant in leaf.variants)
                      VariantRow(
                        variant: variant,
                        depth: depth + 1,
                        active: variant.id == leaf.activeVariant?.id,
                        onTap: () => onSelectVariant(leaf.id, variant.id),
                      ),
                ],
              ),
            ),
          },
        if (onReorder != null)
          _TrailingDropZone(
            onWillAccept: (draggedId) => !ancestorGroupIds.contains(draggedId),
            onAccept: (draggedId) =>
                onReorder!(draggedId, ownParentId, nodes.length),
          ),
      ],
    );
  }

  /// Оборачивает [child] в `Draggable`+`DragTarget`, если `onReorder`
  /// задан — иначе возвращает [child] как есть (перетаскивание выключено).
  Widget _dragWrap({
    required String nodeId,
    required String feedbackLabel,
    required String? feedbackIcon,
    required void Function(String draggedId) onAccept,
    required Widget child,
  }) {
    if (onReorder == null) return child;

    return DragTarget<String>(
      // details.data != nodeId — не дропать узел сам на себя (не меняет
      // порядок, no-op). !ancestorGroupIds.contains — не дать перетащить
      // группу-предка внутрь одного из её же потомков (сюда попадает и
      // сама группа этого узла, если nodeId — id группы: см.
      // ancestorGroupIds в конструкторе ProxyTreeList).
      onWillAcceptWithDetails: (details) =>
          details.data != nodeId && !ancestorGroupIds.contains(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final draggedChild = hovering
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: PortColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                child: child,
              )
            : child;

        // Обычный Draggable стартует перетаскивание с первого же движения
        // пальца — на мышке это нормально (клик и сразу тащим), но на
        // тачскрине так легко случайно сдвинуть элемент вместо тапа/скролла
        // списка. LongPressDraggable — тот же виджет, но с задержкой перед
        // стартом (используем платформенный дефолт `kLongPressTimeout`).
        if (Platform.isAndroid || Platform.isIOS) {
          return LongPressDraggable<String>(
            data: nodeId,
            feedback: _DragFeedback(label: feedbackLabel, icon: feedbackIcon),
            childWhenDragging: Opacity(opacity: 0.4, child: child),
            child: draggedChild,
          );
        }

        return Draggable<String>(
          data: nodeId,
          feedback: _DragFeedback(label: feedbackLabel, icon: feedbackIcon),
          childWhenDragging: Opacity(opacity: 0.4, child: child),
          child: draggedChild,
        );
      },
    );
  }
}

/// Полоса-приёмник в конце списка узлов одного уровня — дроп на неё
/// добавляет перетаскиваемый узел последним элементом этого уровня.
class _TrailingDropZone extends StatelessWidget {
  final bool Function(String draggedId)? onWillAccept;
  final void Function(String draggedId) onAccept;
  const _TrailingDropZone({this.onWillAccept, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: onWillAccept == null
          ? null
          : (details) => onWillAccept!(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: hovering ? 20 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: hovering
                ? PortColors.accent.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final String label;
  final String? icon;
  const _DragFeedback({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PortColors.popover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PortColors.border),
        boxShadow: [
          BoxShadow(
            color: PortColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ServerIcon(icon: icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: PortText.small),
          ],
        ),
      ),
    );
  }
}

/// Строка псевдо-узла "Авто" — клик один раз выбирает сервер с наименьшей
/// задержкой среди листьев группы (см. `pick_best_by_latency.dart`); сам
/// результат подсвечивается как обычная выбранная строка сервера в другом
/// месте дерева, не здесь — см. ROADMAP.md, трек 5.
class _AutoRow extends StatefulWidget {
  final AutoSelectMarker marker;
  final int depth;
  final VoidCallback onTap;

  const _AutoRow({required this.marker, required this.depth, required this.onTap});

  @override
  State<_AutoRow> createState() => _AutoRowState();
}

class _AutoRowState extends State<_AutoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered
        ? PortColors.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: EdgeInsets.fromLTRB(10 + 14.0 * widget.depth, 8, 10, 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 15, color: PortColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.marker.name,
                  style: PortText.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatefulWidget {
  final ServerGroup group;
  final int depth;
  final bool expanded;
  final VoidCallback onTap;

  const _GroupRow({
    required this.group,
    required this.depth,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered
        ? PortColors.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: EdgeInsets.fromLTRB(10 + 14.0 * widget.depth, 8, 10, 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.expanded ? LucideIcons.folderOpen : LucideIcons.folder,
                size: 15,
                color: PortColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.group.name,
                  style: PortText.small.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                widget.expanded
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
                size: 14,
                color: PortColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
