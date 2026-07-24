import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/proxy_node.dart';
import 'expanded_nodes_provider.dart';
import 'flatten_leaves.dart';
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
  // Пункт "Роутинг" — доступен и standalone-серверам, и серверам внутри
  // подписки (см. ROADMAP.md, трек 3).
  final ValueChanged<String>? onEditRoutingLeaf;
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
  final void Function(String groupId, List<ServerLeaf> leavesInGroup)?
  onSelectAuto;

  const ProxyTreeList({
    super.key,
    required this.nodes,
    this.depth = 0,
    required this.selectedLeafId,
    required this.onSelectLeaf,
    required this.onSelectVariant,
    this.onHideLeaf,
    this.onEditRoutingLeaf,
    this.onPingLeaf,
    this.latencyForLeaf,
    this.pingingLeafIds = const {},
    this.parentGroupId,
    this.onSelectAuto,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(expandedNodesProvider);
    final toggle = ref.read(expandedNodesProvider.notifier).toggle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in nodes)
          switch (node) {
            ServerGroup group => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupRow(
                  group: group,
                  depth: depth,
                  expanded: expanded.contains(group.id),
                  onTap: () => toggle(group.id),
                ),
                if (expanded.contains(group.id))
                  ProxyTreeList(
                    nodes: group.children,
                    depth: depth + 1,
                    selectedLeafId: selectedLeafId,
                    onSelectLeaf: onSelectLeaf,
                    onSelectVariant: onSelectVariant,
                    onHideLeaf: onHideLeaf,
                    onEditRoutingLeaf: onEditRoutingLeaf,
                    onPingLeaf: onPingLeaf,
                    latencyForLeaf: latencyForLeaf,
                    pingingLeafIds: pingingLeafIds,
                    parentGroupId: group.id,
                    onSelectAuto: onSelectAuto,
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
                  ServerRow(
                    leaf: leaf,
                    depth: depth,
                    selected: leaf.id == selectedLeafId,
                    expanded: expanded.contains(leaf.id),
                    onSelect: () => onSelectLeaf(leaf.id),
                    onToggleExpand: () => toggle(leaf.id),
                    onHide: onHideLeaf == null
                        ? null
                        : () => onHideLeaf!(leaf.id),
                    onEditRouting: onEditRoutingLeaf == null
                        ? null
                        : () => onEditRoutingLeaf!(leaf.id),
                    latencyMs: latencyForLeaf?.call(leaf.id),
                    pinging: pingingLeafIds.contains(leaf.id),
                    onPing: onPingLeaf == null
                        ? null
                        : () => onPingLeaf!(leaf.id),
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
      ],
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final background = _hovered
        ? scheme.accent.withValues(alpha: 0.5)
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
              Icon(LucideIcons.zap, size: 15, color: scheme.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.marker.name,
                  style: theme.textTheme.small,
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final background = _hovered
        ? scheme.accent.withValues(alpha: 0.5)
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
                color: scheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.group.name,
                  style: theme.textTheme.small.copyWith(
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
                color: scheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
