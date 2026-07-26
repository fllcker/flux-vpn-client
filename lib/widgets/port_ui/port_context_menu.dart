part of 'port_ui.dart';

/// ContextMenu — context-menu.tsx. Открывается по правому клику в точке
/// курсора, content = popover card, item = rounded-sm + hover bg-accent,
/// destructive item = text-destructive + hover bg-destructive/10(20 dark).
/// Без submenu — приложению они пока не нужны (см. docs/shadcn/PLAN.md для
/// submenu-варианта в playground, если понадобится).
class PortContextMenuItem {
  final Widget? leading;
  final Widget child;
  final VoidCallback? onPressed;
  final bool destructive;
  const PortContextMenuItem({this.leading, required this.child, this.onPressed, this.destructive = false});
}

/// Открывает попап меню в точке [globalPosition] — общая реализация,
/// используемая и правым кликом ([PortContextMenuRegion], десктоп), и
/// тапом по отдельной кнопке-троеточию ([PortContextMenuButton], Android/iOS,
/// см. её doc-комментарий про конфликт с drag-n-drop у строк серверов).
void showPortContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<PortContextMenuItem> items,
}) {
  OverlayEntry? entry;
  late AnimationController controller;
  final overlay = Overlay.of(context);
  controller = AnimationController(vsync: Navigator.of(context), duration: _kDuration)..forward();
  void close() async {
    await controller.reverse();
    entry?.remove();
    controller.dispose();
  }

  entry = OverlayEntry(
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      // Простой клэмп в границы окна вместо полноценной Radix
      // collision-логики — этого достаточно для наших контекстных меню.
      final dx = globalPosition.dx.clamp(8.0, size.width - 232);
      final dy = globalPosition.dy.clamp(8.0, size.height - 8);
      return Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: close)),
          Positioned(
            left: dx,
            top: dy,
            child: _PopoverSurface(
              animation: controller,
              origin: Alignment.topLeft,
              child: _ContextMenuSurface(items: items, onItemTap: close),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

class PortContextMenuRegion extends StatelessWidget {
  final Widget child;
  final List<PortContextMenuItem> items;

  const PortContextMenuRegion({super.key, required this.child, required this.items});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          showPortContextMenu(context: context, globalPosition: details.globalPosition, items: items),
      child: child,
    );
  }
}

/// Кнопка-троеточие, открывающая то же меню по тапу — на Android/iOS нет
/// правого клика (`PortContextMenuRegion.onSecondaryTapDown` там недостижим),
/// а навесить открытие меню на long press нельзя: строки серверов уже
/// используют long press для драг-н-дропа (см. `_dragWrap` в
/// `proxy_tree_list.dart`), и два независимых long-press распознавателя на
/// одной строке боролись бы за жест непредсказуемо (Flutter не гарантирует,
/// чей таймер "выиграет" гонку). Обычный тап на отдельный виджет никакого
/// пересечения с драгом не создаёт.
class PortContextMenuButton extends StatelessWidget {
  final List<PortContextMenuItem> items;
  const PortContextMenuButton({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => PortIconButton.ghost(
        icon: const Icon(Icons.more_vert, size: 18),
        size: 32,
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          final position = box.localToGlobal(Offset(box.size.width, box.size.height));
          showPortContextMenu(context: context, globalPosition: position, items: items);
        },
      ),
    );
  }
}

class _ContextMenuSurface extends StatelessWidget {
  final List<PortContextMenuItem> items;
  final VoidCallback onItemTap;
  const _ContextMenuSurface({required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PortColors.popover,
          borderRadius: BorderRadius.circular(kRadius * 0.8),
          border: Border.all(color: PortColors.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final item in items) _ContextMenuItemTile(item: item, onSelected: onItemTap)],
        ),
      ),
    );
  }
}

class _ContextMenuItemTile extends StatefulWidget {
  final PortContextMenuItem item;
  final VoidCallback onSelected;
  const _ContextMenuItemTile({required this.item, required this.onSelected});

  @override
  State<_ContextMenuItemTile> createState() => _ContextMenuItemTileState();
}

class _ContextMenuItemTileState extends State<_ContextMenuItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final destructive = widget.item.destructive;
    final fg = destructive ? PortColors.destructive : (_hovered ? PortColors.accentForeground : PortColors.foreground);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          widget.item.onPressed?.call();
          widget.onSelected();
        },
        child: AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? (destructive ? PortColors.destructive.withValues(alpha: 0.2) : PortColors.accent)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius * 0.6),
          ),
          child: Row(
            children: [
              if (widget.item.leading != null) ...[
                IconTheme.merge(data: IconThemeData(color: fg, size: 14), child: widget.item.leading!),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: DefaultTextStyle.merge(style: TextStyle(color: fg, fontSize: 14), child: widget.item.child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
