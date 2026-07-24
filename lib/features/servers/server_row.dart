import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/proxy_node.dart';
import 'server_icon.dart';

/// Строка сервера. Один вариант подключения — клик сразу выбирает сервер.
/// Несколько вариантов — клик разворачивает список вариантов прямо под
/// строкой (см. ProxyTreeList), без поповеров/оверлеев.
class ServerRow extends StatefulWidget {
  final ServerLeaf leaf;
  final int depth;
  final bool selected;
  final bool expanded;
  final VoidCallback onSelect;
  final VoidCallback onToggleExpand;
  // Скрытие доступно только серверам внутри подписки, не standalone-нодам
  // (см. ROADMAP.md, трек 2) — null здесь значит "не показывать пункт".
  final VoidCallback? onHide;

  const ServerRow({
    super.key,
    required this.leaf,
    required this.depth,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onToggleExpand,
    this.onHide,
  });

  @override
  State<ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<ServerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final background = widget.selected
        ? scheme.accent
        : _hovered
        ? scheme.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);

    final row = _buildRow(theme, scheme, background);
    final onHide = widget.onHide;
    if (onHide == null) return row;

    return ShadContextMenuRegion(
      items: [
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.eyeOff, size: 14),
          onPressed: onHide,
          child: const Text('Скрыть'),
        ),
      ],
      child: row,
    );
  }

  Widget _buildRow(ShadThemeData theme, ShadColorScheme scheme, Color background) {
    final hasVariantChoice = widget.leaf.variants.length > 1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: hasVariantChoice
            ? () {
                widget.onSelect();
                widget.onToggleExpand();
              }
            : widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(10 + 14.0 * widget.depth, 8, 10, 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: hasVariantChoice ? 28 : 20,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? scheme.primary
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              ServerIcon(icon: widget.leaf.icon, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.leaf.name,
                      style: theme.textTheme.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasVariantChoice)
                      Text(
                        widget.leaf.activeVariant?.label ?? '',
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (hasVariantChoice)
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

/// Строка одного варианта подключения под развёрнутым [ServerRow].
class VariantRow extends StatefulWidget {
  final ConnectionVariant variant;
  final int depth;
  final bool active;
  final VoidCallback onTap;

  const VariantRow({
    super.key,
    required this.variant,
    required this.depth,
    required this.active,
    required this.onTap,
  });

  @override
  State<VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<VariantRow> {
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
          padding: EdgeInsets.fromLTRB(10 + 14.0 * widget.depth, 7, 10, 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.variant.label,
                  style: theme.textTheme.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.active)
                Icon(
                  LucideIcons.check,
                  size: 13,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
