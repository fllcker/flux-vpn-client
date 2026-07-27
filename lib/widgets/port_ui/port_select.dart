part of 'port_ui.dart';

/// Select — select.tsx. Trigger = та же bg-input/30 hover/50 формула, что у
/// Input/outline-Button. Content = popover card, Item = rounded-sm + hover
/// bg-accent + чекмарк у выбранного (см. IntrinsicWidth-фикс в
/// docs/shadcn/PLAN.md — попап должен быть шире контента ровно на отступ
/// под чекмарк, иначе чекмарк рендерится за пределами карточки).
class PortSelectOption<T> {
  final T value;
  final Widget child;
  const PortSelectOption({required this.value, required this.child});
}

class PortSelect<T> extends StatefulWidget {
  final T? initialValue;
  final ValueChanged<T?> onChanged;
  final List<PortSelectOption<T>> options;
  final Widget Function(BuildContext context, T value) selectedOptionBuilder;
  final double minWidth;

  const PortSelect({
    super.key,
    this.initialValue,
    required this.onChanged,
    required this.options,
    required this.selectedOptionBuilder,
    this.minWidth = 140,
  });

  @override
  State<PortSelect<T>> createState() => _PortSelectState<T>();
}

class _PortSelectState<T> extends State<PortSelect<T>> with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  final _triggerKey = GlobalKey();
  OverlayEntry? _entry;
  late T? _value = widget.initialValue;
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _kDuration, reverseDuration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _entry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _entry == null ? _open() : _close();

  void _select(T value) {
    setState(() => _value = value);
    widget.onChanged(value);
    _close();
  }

  void _open() {
    final box = _triggerKey.currentContext!.findRenderObject() as RenderBox;
    final triggerWidth = box.size.width;
    final effectiveMinWidth = triggerWidth < widget.minWidth ? widget.minWidth : triggerWidth;

    // Попап растёт от левого края триггера вправо по умолчанию (как раньше),
    // без учёта границ экрана — на триггере, прижатом к правому краю ряда
    // (см. `_SettingRow` в settings_page.dart), длинная опция вроде "С
    // правами администратора" вылезала за пределы окна и обрезалась. Решаем
    // один раз при открытии: считаем, с какой стороны от триггера реально
    // больше места, и растим попап в ту сторону, дополнительно ограничивая
    // его ширину этим пространством — так он физически не может вылезти за
    // край окна, даже если опция окажется ещё длиннее.
    final triggerGlobalLeft = box.localToGlobal(Offset.zero).dx;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const margin = 8.0;
    final spaceRight = screenWidth - triggerGlobalLeft - margin;
    final spaceLeft = triggerGlobalLeft + triggerWidth - margin;
    final growLeft = spaceLeft > spaceRight;
    final maxPopoverWidth = (growLeft ? spaceLeft : spaceRight).clamp(
      effectiveMinWidth,
      double.infinity,
    );
    final anchor = growLeft ? Alignment.topRight : Alignment.topLeft;

    _entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _close,
          child: Stack(
            children: [
              const Positioned.fill(child: SizedBox.shrink()),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: anchor,
                followerAnchor: anchor,
                offset: const Offset(0, 4),
                child: _PopoverSurface(
                  animation: _controller,
                  child: Align(
                    alignment: anchor,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: effectiveMinWidth,
                        maxWidth: maxPopoverWidth,
                      ),
                      child: _SelectContent<T>(
                        options: widget.options,
                        value: _value,
                        onSelected: _select,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    _controller.forward(from: 0);
    setState(() {});
  }

  Future<void> _close() async {
    if (_entry == null) return;
    await _controller.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final open = _entry != null;
    return CompositedTransformTarget(
      link: _layerLink,
      child: _Interactive(
        onTap: _toggle,
        builder: (context, {required hovered, required focused, required pressed}) {
          final overlayAlpha = hovered || open ? 0.15 * 0.50 : 0.15 * 0.30;
          final bg = Color.lerp(PortColors.background, Colors.white, overlayAlpha)!;
          return AnimatedContainer(
            key: _triggerKey,
            duration: _kDuration,
            curve: _kEase,
            height: 36,
            constraints: BoxConstraints(minWidth: widget.minWidth),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(kRadius * 0.8),
              border: Border.all(color: focused ? PortColors.ring : PortColors.inputBorder),
              boxShadow: [
                const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 1), blurRadius: 2),
                if (focused) BoxShadow(color: PortColors.ring.withValues(alpha: 0.5), spreadRadius: 3),
              ],
            ),
            // justify-between в исходнике — контент слева, шеврон прижат
            // вправо.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: PortColors.foreground, fontSize: 14, height: 1),
                    child: _value == null ? const SizedBox.shrink() : widget.selectedOptionBuilder(context, _value as T),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: PortColors.mutedForeground,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectContent<T> extends StatelessWidget {
  final List<PortSelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onSelected;

  const _SelectContent({required this.options, required this.value, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: PortColors.popover,
          borderRadius: BorderRadius.circular(kRadius * 0.8),
          border: Border.all(color: PortColors.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 12, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          // IntrinsicWidth — иначе ширина попапа считается только от
          // triggerWidth/minWidth, без учёта того, что каждому item ещё
          // нужен запас под чекмарк (pr-8) справа от текста — см.
          // docs/shadcn/PLAN.md.
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in options)
                  _SelectItem<T>(option: option, selected: option.value == value, onTap: () => onSelected(option.value)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectItem<T> extends StatefulWidget {
  final PortSelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  const _SelectItem({required this.option, required this.selected, required this.onTap});

  @override
  State<_SelectItem<T>> createState() => _SelectItemState<T>();
}

class _SelectItemState<T> extends State<_SelectItem<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          padding: const EdgeInsets.fromLTRB(8, 6, 32, 6),
          decoration: BoxDecoration(
            color: _hovered ? PortColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius * 0.6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: _hovered ? PortColors.accentForeground : PortColors.foreground,
                  fontSize: 14,
                ),
                child: widget.option.child,
              ),
              if (widget.selected)
                Positioned(
                  right: -24,
                  top: 0,
                  bottom: 0,
                  child: Icon(Icons.check, size: 16, color: PortColors.foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
