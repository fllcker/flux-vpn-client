import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core_abstraction/proxy_node.dart';
import '../../widgets/port_ui/port_ui.dart';
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
  final VoidCallback? onEditRouting;
  // Задержка из кэша пинга (см. ROADMAP.md, трек 4) — null значит "ещё не
  // измеряли". onPing == null скрывает индикатор целиком.
  final int? latencyMs;
  final bool pinging;
  final VoidCallback? onPing;

  const ServerRow({
    super.key,
    required this.leaf,
    required this.depth,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onToggleExpand,
    this.onHide,
    this.onEditRouting,
    this.latencyMs,
    this.pinging = false,
    this.onPing,
  });

  @override
  State<ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<ServerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? PortColors.accent
        : _hovered
        ? PortColors.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);

    final row = _buildRow(background);
    final onHide = widget.onHide;
    final onEditRouting = widget.onEditRouting;
    if (onHide == null && onEditRouting == null) return row;

    return PortContextMenuRegion(
      items: [
        if (onEditRouting != null)
          PortContextMenuItem(
            leading: const Icon(LucideIcons.route, size: 14),
            onPressed: onEditRouting,
            child: const Text('Роутинг'),
          ),
        if (onHide != null)
          PortContextMenuItem(
            leading: const Icon(LucideIcons.eyeOff, size: 14),
            onPressed: onHide,
            child: const Text('Скрыть'),
          ),
      ],
      child: row,
    );
  }

  Widget _buildRow(Color background) {
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
                      ? PortColors.primary
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
                      style: PortText.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasVariantChoice)
                      Text(
                        widget.leaf.activeVariant?.label ?? '',
                        style: PortText.muted.copyWith(
                          fontSize: 11,
                          height: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (widget.onPing != null)
                _PingIndicator(
                  latencyMs: widget.latencyMs,
                  pinging: widget.pinging,
                  onPing: widget.onPing!,
                ),
              if (hasVariantChoice)
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

/// Задержка сервера — тап заново запускает замер. Обёрнут в свой
/// `GestureDetector`, вложенный в тап-область всей строки: Flutter
/// разрешает такую вложенность в пользу самого внутреннего распознавателя
/// (обычный паттерн — иконка-кнопка внутри кликабельного `ListTile`).
class _PingIndicator extends StatelessWidget {
  final int? latencyMs;
  final bool pinging;
  final VoidCallback onPing;

  const _PingIndicator({
    required this.latencyMs,
    required this.pinging,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    if (pinging) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '…',
          style: PortText.muted.copyWith(fontSize: 11),
        ),
      );
    }

    return GestureDetector(
      onTap: onPing,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          latencyMs == null ? '—' : '${latencyMs}ms',
          style: PortText.muted.copyWith(
            fontSize: 11,
            color: _latencyColor(latencyMs) ?? PortColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Color? _latencyColor(int? ms) {
    if (ms == null) return null;
    if (ms < 100) return const Color(0xFF4ADE80);
    if (ms < 300) return const Color(0xFFFACC15);
    return const Color(0xFFF87171);
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
                  style: PortText.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.active)
                const Icon(
                  LucideIcons.check,
                  size: 13,
                  color: PortColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
