part of 'port_ui.dart';

/// ContextMenu — context-menu.tsx. Открывается по правому клику в точке
/// курсора, content = popover card, item = rounded-sm + hover bg-accent,
/// destructive item = text-destructive + hover bg-destructive/10(20 dark).
/// [submenu] — вложенный список пунктов (ContextMenuSub), см.
/// docs/shadcn/PLAN.md, "Submenu" — открывается наведением (как и положено
/// меню — не тапом/кликом, см. `_SubmenuController`), с fallback на тап для
/// тач-устройств, где ховера не существует. Закрывается вместе со всей
/// цепочкой меню при выборе любого вложенного пункта.
class PortContextMenuItem {
  final Widget? leading;
  final Widget child;
  final VoidCallback? onPressed;
  final bool destructive;
  final List<PortContextMenuItem>? submenu;
  const PortContextMenuItem({
    this.leading,
    required this.child,
    this.onPressed,
    this.destructive = false,
    this.submenu,
  });
}

/// Открывает попап меню в точке [globalPosition] — общая реализация,
/// используемая и правым кликом ([PortContextMenuRegion], десктоп), и
/// тапом по отдельной кнопке-троеточию ([PortContextMenuButton], Android/iOS,
/// см. её doc-комментарий про конфликт с drag-n-drop у строк серверов).
///
/// Растёт вниз от [globalPosition] по умолчанию, но переворачивается вверх
/// (нижний край меню фиксируется в точке анкора), если снизу меньше места,
/// чем сверху, и его в принципе не хватает — иначе меню, открытое рядом с
/// нижним краем экрана (например, кнопка ближе к низу панели), обрезалось
/// по границе окна и часть пунктов становилась некликабельной.
void showPortContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<PortContextMenuItem> items,
}) {
  OverlayEntry? entry;
  late AnimationController controller;
  final overlay = Overlay.of(context);
  controller = AnimationController(vsync: Navigator.of(context), duration: _kDuration)..forward();
  var closed = false;
  void close() async {
    if (closed) return;
    closed = true;
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
      final spaceBelow = size.height - globalPosition.dy;
      final spaceAbove = globalPosition.dy;
      final growUp = spaceBelow < 260 && spaceAbove > spaceBelow;
      return Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: close)),
          Positioned(
            left: dx,
            top: growUp ? null : globalPosition.dy.clamp(8.0, size.height - 8),
            bottom: growUp ? (size.height - globalPosition.dy).clamp(8.0, size.height - 8) : null,
            child: _PopoverSurface(
              animation: controller,
              origin: growUp ? Alignment.bottomLeft : Alignment.topLeft,
              child: _ContextMenuSurface(items: items, onItemTap: close, rootClose: close),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

/// Координирует подменю ОДНОГО уровня меню (все пункты одного
/// [_ContextMenuSurface] делят один инстанс): открытие по ховеру — с
/// небольшой задержкой (не открывать, пока курсор просто "проезжает" мимо
/// по пути к другому пункту), закрытие — тоже с задержкой и отменяется,
/// если курсор успел зайти в само подменю (иначе диагональное движение
/// мыши к пункту подменю задевало бы промежуток и закрывало его). Открыт
/// не больше одного подменю на уровень одновременно — новый открывающийся
/// сперва закрывает предыдущий.
class _SubmenuController {
  Timer? _openTimer;
  Timer? _closeTimer;
  VoidCallback? _closeCurrent;
  Object? _openOwner;

  void requestOpen(Object owner, VoidCallback open) {
    _closeTimer?.cancel();
    if (_openOwner == owner) return;
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 120), () {
      _closeCurrent?.call();
      _openOwner = owner;
      _closeCurrent = null;
      open();
    });
  }

  /// Открывает без задержки — используется при тапе (тач-устройства без
  /// ховера должны получить submenu сразу).
  void openImmediately(Object owner, VoidCallback open) {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    if (_openOwner == owner) return;
    _closeCurrent?.call();
    _openOwner = owner;
    _closeCurrent = null;
    open();
  }

  void registerClose(Object owner, VoidCallback close) {
    if (_openOwner == owner) _closeCurrent = close;
  }

  void requestCloseSoon(Object owner) {
    _openTimer?.cancel();
    if (_openOwner != owner) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 250), () {
      _closeCurrent?.call();
      _closeCurrent = null;
      _openOwner = null;
    });
  }

  void cancelClose(Object owner) {
    if (_openOwner == owner) _closeTimer?.cancel();
  }

  /// Ховер на обычный (без submenu) пункт этого же уровня — закрывает
  /// открытое подменю соседа, раз курсор явно ушёл к другому пункту.
  void closeAllSoon() {
    _openTimer?.cancel();
    final owner = _openOwner;
    if (owner == null) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 250), () {
      if (_openOwner == owner) {
        _closeCurrent?.call();
        _closeCurrent = null;
        _openOwner = null;
      }
    });
  }

  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
  }
}

/// Открывает вложенное меню [items] рядом с точкой [anchor] (правый край
/// пункта-родителя) — тот же визуальный стиль, что и корневое меню.
/// [parentController]/[parentOwner] — чтобы наведение на сам попап подменю
/// отменяло его закрытие (см. [_SubmenuController]), иначе курсор,
/// двигающийся из пункта-родителя в открывшееся подменю, проходил бы через
/// "ничью землю" и закрывал его на полпути. [rootClose] закрывает всю
/// цепочку меню целиком (вызывается при выборе любого пункта).
void _showSubmenu({
  required BuildContext context,
  required Offset anchor,
  required List<PortContextMenuItem> items,
  required VoidCallback rootClose,
  required _SubmenuController parentController,
  required Object parentOwner,
}) {
  OverlayEntry? entry;
  late AnimationController controller;
  final overlay = Overlay.of(context);
  controller = AnimationController(vsync: Navigator.of(context), duration: _kDuration)..forward();
  var closed = false;
  void closeThis() async {
    if (closed) return;
    closed = true;
    await controller.reverse();
    entry?.remove();
    controller.dispose();
  }

  parentController.registerClose(parentOwner, closeThis);

  entry = OverlayEntry(
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      final dx = anchor.dx.clamp(8.0, size.width - 232);
      final spaceBelow = size.height - anchor.dy;
      final spaceAbove = anchor.dy;
      final growUp = spaceBelow < 260 && spaceAbove > spaceBelow;
      return Stack(
        children: [
          // Клик мимо любого уровня меню закрывает всю цепочку целиком, не
          // только это подменю — так же ведёт себя Radix/shadcn.
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: rootClose)),
          Positioned(
            left: dx,
            top: growUp ? null : anchor.dy.clamp(8.0, size.height - 8),
            bottom: growUp ? (size.height - anchor.dy).clamp(8.0, size.height - 8) : null,
            child: MouseRegion(
              onEnter: (_) => parentController.cancelClose(parentOwner),
              onExit: (_) => parentController.requestCloseSoon(parentOwner),
              child: _PopoverSurface(
                animation: controller,
                origin: growUp ? Alignment.bottomLeft : Alignment.topLeft,
                child: _ContextMenuSurface(items: items, onItemTap: closeThis, rootClose: rootClose),
              ),
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
  final double size;
  const PortContextMenuButton({super.key, required this.items, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => PortIconButton.ghost(
        icon: const Icon(Icons.more_vert, size: 18),
        size: size,
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          final position = box.localToGlobal(Offset(box.size.width, box.size.height));
          showPortContextMenu(context: context, globalPosition: position, items: items);
        },
      ),
    );
  }
}

class _ContextMenuSurface extends StatefulWidget {
  final List<PortContextMenuItem> items;
  final VoidCallback onItemTap;
  final VoidCallback rootClose;
  const _ContextMenuSurface({required this.items, required this.onItemTap, required this.rootClose});

  @override
  State<_ContextMenuSurface> createState() => _ContextMenuSurfaceState();
}

class _ContextMenuSurfaceState extends State<_ContextMenuSurface> {
  final _submenuController = _SubmenuController();

  @override
  void dispose() {
    _submenuController.dispose();
    super.dispose();
  }

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
          children: [
            for (final item in widget.items)
              _ContextMenuItemTile(
                item: item,
                onItemTap: widget.onItemTap,
                rootClose: widget.rootClose,
                controller: _submenuController,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextMenuItemTile extends StatefulWidget {
  final PortContextMenuItem item;
  // Закрывает меню, к которому принадлежит этот пункт (подменю или
  // корневое) — используется для обычных (без submenu) пунктов.
  final VoidCallback onItemTap;
  // Закрывает всю цепочку меню целиком — используется, когда выбор
  // происходит внутри подменю (нужно убрать и подменю, и его родителя).
  final VoidCallback rootClose;
  final _SubmenuController controller;
  const _ContextMenuItemTile({
    required this.item,
    required this.onItemTap,
    required this.rootClose,
    required this.controller,
  });

  @override
  State<_ContextMenuItemTile> createState() => _ContextMenuItemTileState();
}

class _ContextMenuItemTileState extends State<_ContextMenuItemTile> {
  bool _hovered = false;
  final Object _ownerId = Object();

  void _openSubmenu(List<PortContextMenuItem> submenu, {required bool immediate}) {
    final box = context.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset(box.size.width, 0));
    void open() => _showSubmenu(
      context: context,
      anchor: anchor,
      items: submenu,
      rootClose: widget.rootClose,
      parentController: widget.controller,
      parentOwner: _ownerId,
    );
    if (immediate) {
      widget.controller.openImmediately(_ownerId, open);
    } else {
      widget.controller.requestOpen(_ownerId, open);
    }
  }

  void _handleTap() {
    final submenu = widget.item.submenu;
    if (submenu != null) {
      // Тач-устройства не шлют hover-событий вообще — тап должен открывать
      // подменю сразу, а не полагаться на наведение.
      _openSubmenu(submenu, immediate: true);
      return;
    }
    widget.item.onPressed?.call();
    widget.onItemTap();
    widget.rootClose();
  }

  void _handleHoverEnter() {
    setState(() => _hovered = true);
    final submenu = widget.item.submenu;
    if (submenu != null) {
      _openSubmenu(submenu, immediate: false);
    } else {
      widget.controller.closeAllSoon();
    }
  }

  void _handleHoverExit() {
    setState(() => _hovered = false);
    if (widget.item.submenu != null) {
      widget.controller.requestCloseSoon(_ownerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destructive = widget.item.destructive;
    final fg = destructive ? PortColors.destructive : (_hovered ? PortColors.accentForeground : PortColors.foreground);
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: GestureDetector(
        onTap: _handleTap,
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
              if (widget.item.submenu != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
