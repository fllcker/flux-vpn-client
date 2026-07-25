import 'dart:async';

import 'package:flutter/material.dart';

/// Тестовая песочница для ручного 1:1 порта shadcn/ui компонентов.
///
/// Цвета — это OKLCH-токены из `apps/v4/registry/new-york-v4` (dark theme,
/// base color "neutral"), пересчитанные в sRGB вручную (OKLab -> linear ->
/// gamma), НЕ через приблизительные HSL-аналоги. Классы взяты дословно из
/// *.tsx в репозитории shadcn-ui/ui и переведены построчно в
/// decoration/interaction-стейты. Полный разбор — в docs/shadcn/PLAN.md.
///
/// Радиус-шкала (см. --radius-* в globals.css shadcn):
///   rounded-sm = radius*0.6, rounded-md = radius*0.8, rounded-lg = radius*1.0,
///   rounded-xl = radius*1.4, rounded-full = фиксированные 999.
/// Каждый виджет ниже сам применяет свой множитель к переданному `radius`.
class _Tokens {
  // :root .dark, base color "neutral" — https://ui.shadcn.com
  static const background = Color(0xFF0A0A0A);
  static const foreground = Color(0xFFFAFAFA);
  static const card = Color(0xFF171717);
  static const popover = card;
  static const popoverForeground = foreground;
  static const primary = Color(0xFFE5E5E5);
  static const primaryForeground = Color(0xFF171717);
  static const secondary = Color(0xFF262626);
  static const secondaryForeground = Color(0xFFFAFAFA);
  static const muted = Color(0xFF262626);
  static const mutedForeground = Color(0xFFA1A1A1);
  static const accent = Color(0xFF404040);
  static const accentForeground = Color(0xFFFAFAFA);
  static const destructive = Color(0xFFFF6466);
  static const ring = Color(0xFF737373);

  // Эти два токена в CSS хранятся уже С альфой:
  // --border: oklch(1 0 0 / 10%) --input: oklch(1 0 0 / 15%)
  // Модификатор Tailwind bg-input/30 делает color-mix(input 30%, transparent)
  // -> итоговая альфа = 0.15 * 0.30, а не 30% сама по себе (color-mix
  // перемножает альфы по спецификации CSS).
  static const border = Color.fromRGBO(255, 255, 255, 0.10);
  static const inputBorder = Color.fromRGBO(255, 255, 255, 0.15);
}

const _kEase = Cubic(0.4, 0, 0.2, 1); // tailwind default transition easing
const _kDuration = Duration(milliseconds: 150); // tailwind default duration

/// --radius (в px). Единственный настраиваемый токен — rounded-md = radius*0.8
/// и т.д. (см. шкалу выше), badge/switch всегда rounded-full независимо от
/// него. Дефолт shadcn/ui — 10px (0.625rem); 24px — то, что визуально
/// совпало со скриншотом-референсом в docs/shadcn.
const kRadius = 24.0;

// ---------------------------------------------------------------------------
// Общая интерактивная обвязка (hover/focus/press) — используется Button,
// IconButton, Select-триггером и т.п., чтобы не дублировать три setState-флага
// в каждом виджете отдельно.
// ---------------------------------------------------------------------------

typedef _InteractiveBuilder = Widget Function(
  BuildContext context, {
  required bool hovered,
  required bool focused,
  required bool pressed,
});

class _Interactive extends StatefulWidget {
  final _InteractiveBuilder builder;
  final VoidCallback? onTap;
  final bool scaleOnPress;

  const _Interactive({
    required this.builder,
    this.onTap,
    this.scaleOnPress = true,
  });

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final content = widget.builder(
      context,
      hovered: _hovered,
      focused: _focused,
      pressed: _pressed,
    );
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: widget.scaleOnPress
                ? AnimatedScale(
                    scale: _pressed && !disabled ? 0.98 : 1,
                    duration: const Duration(milliseconds: 90),
                    curve: _kEase,
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Button / IconButton — button.tsx. variant и size ортогональны в исходнике:
// IconButton — это не отдельный компонент, а Button с size="icon".
// ---------------------------------------------------------------------------

enum PortButtonVariant { primary, secondary, outline, ghost, destructive }

class _ButtonVisual {
  final Color bg;
  final Color? border;
  final Color fg;
  final List<BoxShadow> shadow;
  const _ButtonVisual({required this.bg, this.border, required this.fg, this.shadow = const []});
}

_ButtonVisual _resolveButtonVisual(
  PortButtonVariant variant, {
  required bool hovered,
  required bool focused,
}) {
  Color bg;
  Color? border;
  Color fg;
  List<BoxShadow> shadow = [];

  switch (variant) {
    case PortButtonVariant.primary:
      // bg-primary text-primary-foreground hover:bg-primary/90
      bg = hovered ? Color.lerp(_Tokens.background, _Tokens.primary, 0.9)! : _Tokens.primary;
      fg = _Tokens.primaryForeground;
      break;
    case PortButtonVariant.secondary:
      // bg-secondary text-secondary-foreground hover:bg-secondary/80
      bg = hovered ? Color.lerp(_Tokens.background, _Tokens.secondary, 0.8)! : _Tokens.secondary;
      fg = _Tokens.secondaryForeground;
      break;
    case PortButtonVariant.outline:
      // border bg-background shadow-xs hover:bg-accent
      // dark:border-input dark:bg-input/30 dark:hover:bg-input/50
      final overlayAlpha = hovered ? 0.15 * 0.50 : 0.15 * 0.30;
      bg = Color.lerp(_Tokens.background, Colors.white, overlayAlpha)!;
      border = _Tokens.inputBorder;
      fg = _Tokens.foreground;
      shadow = const [
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 1), blurRadius: 2),
      ];
      break;
    case PortButtonVariant.ghost:
      // hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50
      bg = hovered ? Color.lerp(_Tokens.background, _Tokens.accent, 0.5)! : Colors.transparent;
      fg = _Tokens.foreground;
      break;
    case PortButtonVariant.destructive:
      // bg-destructive text-white hover:bg-destructive/90 dark:bg-destructive/60
      // Прим.: точный каскад hover+dark в реальном Tailwind неоднозначен без
      // сборки (obе модификатора той же специфичности) — берём dark-базу 60%
      // и слегка приглушаем на hover, тем же паттерном, что и primary/secondary.
      bg = Color.lerp(_Tokens.background, _Tokens.destructive, hovered ? 0.5 : 0.6)!;
      fg = Colors.white;
      break;
  }

  return _ButtonVisual(bg: bg, border: border, fg: fg, shadow: shadow);
}

BoxDecoration _focusRingDecoration(_ButtonVisual v, double radius, bool focused) {
  var border = v.border;
  var shadow = v.shadow;
  if (focused) {
    border = _Tokens.ring;
    shadow = [...shadow, BoxShadow(color: _Tokens.ring.withValues(alpha: 0.5), spreadRadius: 3)];
  }
  return BoxDecoration(
    color: v.bg,
    borderRadius: BorderRadius.circular(radius),
    border: border != null ? Border.all(color: border) : null,
    boxShadow: shadow,
  );
}

class PortButton extends StatelessWidget {
  final String label;
  final PortButtonVariant variant;
  final double radius;
  final VoidCallback? onPressed;

  const PortButton({
    super.key,
    required this.label,
    required this.radius,
    this.variant = PortButtonVariant.primary,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _Interactive(
      onTap: onPressed,
      builder: (context, {required hovered, required focused, required pressed}) {
        final v = _resolveButtonVisual(variant, hovered: hovered, focused: focused);
        return AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          height: 36, // h-9
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          decoration: _focusRingDecoration(v, radius * 0.8, focused),
          // Row(mainAxisSize: min) вместо Container.alignment — у Container
          // без явной width, но с alignment, RenderPositionedBox
          // разворачивается на весь bounded простор (капкан Flutter), а нам
          // нужен inline-flex, сжатый по содержимому.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: _kDuration,
                curve: _kEase,
                style: TextStyle(color: v.fg, fontSize: 14, fontWeight: FontWeight.w500, height: 1),
                child: Text(label),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PortIconButton extends StatelessWidget {
  final IconData icon;
  final PortButtonVariant variant;
  final double radius;
  final double size; // size-9 по умолчанию (36)
  final VoidCallback? onPressed;

  const PortIconButton({
    super.key,
    required this.icon,
    required this.radius,
    this.variant = PortButtonVariant.outline,
    this.size = 36,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _Interactive(
      onTap: onPressed,
      builder: (context, {required hovered, required focused, required pressed}) {
        final v = _resolveButtonVisual(variant, hovered: hovered, focused: focused);
        return AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          width: size,
          height: size,
          decoration: _focusRingDecoration(v, radius * 0.8, focused),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: v.fg), // [&_svg]:size-4
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Input — input.tsx (см. заметку в PortInput про кастомную заливку под скрин)
// ---------------------------------------------------------------------------

class PortInput extends StatefulWidget {
  final String placeholder;
  final double radius;

  const PortInput({super.key, required this.placeholder, required this.radius});

  @override
  State<PortInput> createState() => _PortInputState();
}

class _PortInputState extends State<PortInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Дефолтный input.tsx: border border-input bg-transparent
    // dark:bg-input/30 (тонкая обводка, почти прозрачная заливка). На
    // скрине с shadcn.com инпут выглядит иначе — залит сплошным цветом
    // (как secondary-кнопка), без видимой обводки в состоянии покоя. Это
    // явно кастомная демка, но раз просили матчить именно скрин — берём
    // secondary-заливку и обводку показываем только на focus (ring),
    // как единственный сохранённый интерактивный сигнал.
    return AnimatedContainer(
      duration: _kDuration,
      curve: _kEase,
      height: 36,
      decoration: BoxDecoration(
        color: _Tokens.secondary,
        borderRadius: BorderRadius.circular(widget.radius * 0.8),
        border: Border.all(color: _focused ? _Tokens.ring : Colors.transparent),
        boxShadow: [
          if (_focused) BoxShadow(color: _Tokens.ring.withValues(alpha: 0.5), spreadRadius: 3),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
      alignment: Alignment.centerLeft,
      child: TextField(
        focusNode: _focusNode,
        style: const TextStyle(color: _Tokens.foreground, fontSize: 14),
        cursorColor: _Tokens.primary,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: widget.placeholder,
          hintStyle: const TextStyle(color: _Tokens.mutedForeground, fontSize: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge — badge.tsx (rounded-full всегда, независимо от --radius)
// ---------------------------------------------------------------------------

enum PortBadgeVariant { primary, secondary, outline }

class PortBadge extends StatelessWidget {
  final String label;
  final PortBadgeVariant variant;

  const PortBadge({super.key, required this.label, this.variant = PortBadgeVariant.primary});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    Border? border;
    switch (variant) {
      case PortBadgeVariant.primary:
        bg = _Tokens.primary;
        textColor = _Tokens.primaryForeground;
        break;
      case PortBadgeVariant.secondary:
        bg = _Tokens.secondary;
        textColor = _Tokens.secondaryForeground;
        break;
      case PortBadgeVariant.outline:
        bg = Colors.transparent;
        textColor = _Tokens.foreground;
        border = Border.all(color: _Tokens.border);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: border),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Switch — switch.tsx. Трек w-8 h-[1.15rem] (32x18.4), thumb size-4 (16),
// checked: track=primary/thumb=primary-foreground(dark), unchecked:
// track=input(dark)/thumb=foreground(dark).
// ---------------------------------------------------------------------------

class PortSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color trackBaseColor; // фон, НАД которым лежит трек (для альфа-блендинга unchecked)

  const PortSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.trackBaseColor = _Tokens.card,
  });

  static const _w = 32.0;
  static const _h = 18.4;
  static const _thumb = 16.0;
  static const _pad = 2.0;

  @override
  Widget build(BuildContext context) {
    return _Interactive(
      scaleOnPress: false,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      builder: (context, {required hovered, required focused, required pressed}) {
        // dark:data-[state=unchecked]:bg-input/80 -> альфа = 0.15*0.8 = 0.12
        final trackColor = value
            ? _Tokens.primary
            : Color.lerp(trackBaseColor, Colors.white, 0.15 * 0.8)!;
        final thumbColor = value ? _Tokens.primaryForeground : _Tokens.foreground;
        return AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (focused) BoxShadow(color: _Tokens.ring.withValues(alpha: 0.5), spreadRadius: 3),
            ],
          ),
          child: AnimatedAlign(
            duration: _kDuration,
            curve: _kEase,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pad),
              child: Container(
                width: _thumb,
                height: _thumb,
                decoration: BoxDecoration(color: thumbColor, shape: BoxShape.circle),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Popover-подложка (общая fade+zoom-95 анимация для Select/ContextMenu
// контента — data-[state=open]:zoom-in-95 data-[state=open]:fade-in-0)
// ---------------------------------------------------------------------------

class _PopoverSurface extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Alignment origin;

  const _PopoverSurface({required this.animation, required this.child, this.origin = Alignment.topCenter});

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: _kEase, reverseCurve: _kEase);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.95, end: 1.0).animate(curved),
        alignment: origin,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Select — select.tsx. Trigger = outline-button-подобный (та же формула
// bg-input/30 hover/50), Content = popover card, Item = rounded-sm + hover
// bg-accent + чекмарк у выбранного.
// ---------------------------------------------------------------------------

class PortSelect extends StatefulWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final double radius;
  final String? groupLabel;
  // select.tsx: "w-fit" — триггер по умолчанию сжимается по контенту, и
  // justify-between между текстом и шевроном виден, только если у триггера
  // есть собственная ширина (как почти всегда и делают в реальных формах —
  // ср. select-1.png, где бокс явно шире текста).
  final double minWidth;

  const PortSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.radius,
    this.groupLabel,
    this.minWidth = 180,
  });

  @override
  State<PortSelect> createState() => _PortSelectState();
}

class _PortSelectState extends State<PortSelect> with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  final _triggerKey = GlobalKey();
  OverlayEntry? _entry;
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _kDuration, reverseDuration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _entry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    final box = _triggerKey.currentContext!.findRenderObject() as RenderBox;
    final triggerWidth = box.size.width;
    _entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _close,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 4),
                child: _PopoverSurface(
                  animation: _controller,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: triggerWidth < 128 ? 128 : triggerWidth),
                      child: _SelectContent(
                        options: widget.options,
                        value: widget.value,
                        groupLabel: widget.groupLabel,
                        radius: widget.radius,
                        onSelected: (v) {
                          widget.onChanged(v);
                          _close();
                        },
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
          final bg = Color.lerp(_Tokens.background, Colors.white, overlayAlpha)!;
          return AnimatedContainer(
            key: _triggerKey,
            duration: _kDuration,
            curve: _kEase,
            height: 36,
            constraints: BoxConstraints(minWidth: widget.minWidth),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.radius * 0.8),
              border: Border.all(color: focused ? _Tokens.ring : _Tokens.inputBorder),
              boxShadow: [
                const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 1), blurRadius: 2),
                if (focused) BoxShadow(color: _Tokens.ring.withValues(alpha: 0.5), spreadRadius: 3),
              ],
            ),
            // justify-between в исходнике — текст слева, шеврон прижат
            // вправо (заметно только когда триггер шире своего контента).
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.value, style: const TextStyle(color: _Tokens.foreground, fontSize: 14)),
                const SizedBox(width: 8),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: _Tokens.mutedForeground,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectContent extends StatelessWidget {
  final List<String> options;
  final String value;
  final String? groupLabel;
  final double radius;
  final ValueChanged<String> onSelected;

  const _SelectContent({
    required this.options,
    required this.value,
    required this.groupLabel,
    required this.radius,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: _Tokens.popover,
          borderRadius: BorderRadius.circular(radius * 0.8),
          border: Border.all(color: _Tokens.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 12, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          // IntrinsicWidth — иначе ширина попапа считается только от
          // triggerWidth/minWidth(128), без учёта того, что каждому item
          // ещё нужен запас под чекмарк (pr-8) справа от текста: попап
          // получался уже своего же содержимого, и чекмарк у выбранного
          // пункта рендерился за пределами видимой карточки.
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (groupLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Text(groupLabel!, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 12)),
                  ),
                for (final option in options) _SelectItem(label: option, selected: option == value, onTap: () => onSelected(option)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectItem({required this.label, required this.selected, required this.onTap});

  @override
  State<_SelectItem> createState() => _SelectItemState();
}

class _SelectItemState extends State<_SelectItem> {
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
            color: _hovered ? _Tokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius * 0.6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? _Tokens.accentForeground : _Tokens.foreground,
                  fontSize: 14,
                ),
              ),
              if (widget.selected)
                const Positioned(
                  right: -24,
                  top: 0,
                  bottom: 0,
                  child: Icon(Icons.check, size: 16, color: _Tokens.foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog / Alert Dialog — dialog.tsx / alert-dialog.tsx. Overlay black/50
// fade, content rounded-lg(=radius*1.0) border bg-background p-6 shadow-lg,
// zoom-in-95+fade-in-0, duration-200.
// ---------------------------------------------------------------------------

class PortDialogChrome extends StatelessWidget {
  final String title;
  final String description;
  final Widget? content;
  final List<Widget> actions;
  final bool showCloseButton;
  final double radius;

  const PortDialogChrome({
    super.key,
    required this.title,
    required this.description,
    this.content,
    this.actions = const [],
    this.showCloseButton = true,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24), // p-6
        decoration: BoxDecoration(
          color: _Tokens.background,
          borderRadius: BorderRadius.circular(radius), // rounded-lg = radius*1.0
          border: Border.all(color: _Tokens.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _Tokens.foreground, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 14, height: 1.4)),
                if (content != null) ...[const SizedBox(height: 16), content!],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
                  ]),
                ],
              ],
            ),
            if (showCloseButton)
              Positioned(
                top: -8,
                right: -8,
                child: _Interactive(
                  onTap: () => Navigator.of(context).pop(),
                  builder: (context, {required hovered, required focused, required pressed}) {
                    return AnimatedOpacity(
                      duration: _kDuration,
                      opacity: hovered ? 1 : 0.7,
                      child: const Icon(Icons.close, size: 16, color: _Tokens.foreground),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showPortDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dialog',
    barrierDismissible: true, // Radix Dialog по умолчанию закрывается кликом вне контента
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: _kEase, reverseCurve: _kEase);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Sheet — sheet.tsx. Едет с одной из сторон, без скруглений (edge-to-edge),
// border только со стороны, противоположной краю экрана, duration 300/500ms
// (закрытие быстрее открытия — это из исходника, не наша придумка).
// ---------------------------------------------------------------------------

enum PortSheetSide { left, right, top, bottom }

class PortSheetChrome extends StatelessWidget {
  final String title;
  final String description;
  final Widget? content;
  final PortSheetSide side;

  const PortSheetChrome({super.key, required this.title, required this.description, this.content, this.side = PortSheetSide.right});

  @override
  Widget build(BuildContext context) {
    final vertical = side == PortSheetSide.top || side == PortSheetSide.bottom;
    final border = switch (side) {
      PortSheetSide.right => const Border(left: BorderSide(color: _Tokens.border)),
      PortSheetSide.left => const Border(right: BorderSide(color: _Tokens.border)),
      PortSheetSide.top => const Border(bottom: BorderSide(color: _Tokens.border)),
      PortSheetSide.bottom => const Border(top: BorderSide(color: _Tokens.border)),
    };
    final panel = Container(
      width: vertical ? double.infinity : 320, // w-3/4 sm:max-w-sm (упрощено под окно 960px)
      decoration: BoxDecoration(
        color: _Tokens.background,
        border: border,
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 24)],
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16), // p-4
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: _Tokens.foreground, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 14)),
                  if (content != null) ...[const SizedBox(height: 16), content!],
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _Interactive(
                onTap: () => Navigator.of(context).pop(),
                builder: (context, {required hovered, required focused, required pressed}) => AnimatedContainer(
                  duration: _kDuration,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: hovered ? _Tokens.secondary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                  child: AnimatedOpacity(
                    duration: _kDuration,
                    opacity: hovered ? 1 : 0.7,
                    child: const Icon(Icons.close, size: 16, color: _Tokens.foreground),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Align(
      alignment: switch (side) {
        PortSheetSide.right => Alignment.centerRight,
        PortSheetSide.left => Alignment.centerLeft,
        PortSheetSide.top => Alignment.topCenter,
        PortSheetSide.bottom => Alignment.bottomCenter,
      },
      child: vertical ? SizedBox(width: double.infinity, child: panel) : panel,
    );
  }
}

Future<T?> showPortSheet<T>({required BuildContext context, required PortSheetSide side, required WidgetBuilder builder}) {
  final begin = switch (side) {
    PortSheetSide.right => const Offset(1, 0),
    PortSheetSide.left => const Offset(-1, 0),
    PortSheetSide.top => const Offset(0, -1),
    PortSheetSide.bottom => const Offset(0, 1),
  };
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'sheet',
    barrierDismissible: true, // Radix Dialog по умолчанию закрывается кликом вне контента
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300), // data-[state=open]:duration-500 на открытии, 300 закрытие — берём общий 300
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: _kEase, reverseCurve: _kEase);
      return SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(curved), child: child);
    },
  );
}

// ---------------------------------------------------------------------------
// ContextMenu — context-menu.tsx. Открывается по правому клику в точке
// курсора, content = popover card, item = rounded-sm + hover bg-accent,
// destructive item = text-destructive + hover bg-destructive/10(20 в dark).
// ---------------------------------------------------------------------------

sealed class PortContextMenuEntry {
  const PortContextMenuEntry();
}

class PortContextMenuItem extends PortContextMenuEntry {
  final String label;
  final String? shortcut;
  final bool destructive;
  final VoidCallback? onTap;
  final List<PortContextMenuEntry>? submenu;
  const PortContextMenuItem({required this.label, this.shortcut, this.destructive = false, this.onTap, this.submenu});
}

class PortContextMenuSeparator extends PortContextMenuEntry {
  const PortContextMenuSeparator();
}

class PortContextMenuRegion extends StatefulWidget {
  final Widget child;
  final List<PortContextMenuEntry> items;
  final double radius;

  const PortContextMenuRegion({super.key, required this.child, required this.items, required this.radius});

  @override
  State<PortContextMenuRegion> createState() => _PortContextMenuRegionState();
}

class _PortContextMenuRegionState extends State<PortContextMenuRegion> {
  OverlayEntry? _entry;

  void _open(Offset globalPosition) {
    _entry?.remove();
    late AnimationController controller;
    final overlay = Overlay.of(context);
    controller = AnimationController(vsync: Navigator.of(context), duration: _kDuration)..forward();
    void close() async {
      await controller.reverse();
      _entry?.remove();
      _entry = null;
      controller.dispose();
    }

    _entry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        // Простой клэмп в границы окна вместо полноценной Radix
        // collision-логики — этого достаточно для playground.
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
                child: _ContextMenuSurface(items: widget.items, radius: widget.radius, onItemTap: close),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _open(details.globalPosition),
      child: widget.child,
    );
  }
}

class _ContextMenuSurface extends StatelessWidget {
  final List<PortContextMenuEntry> items;
  final double radius;
  final VoidCallback onItemTap;
  const _ContextMenuSurface({required this.items, required this.radius, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _Tokens.popover,
          borderRadius: BorderRadius.circular(radius * 0.8),
          border: Border.all(color: _Tokens.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in items)
              switch (entry) {
                PortContextMenuSeparator() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, color: _Tokens.border),
                  ),
                PortContextMenuItem() => _ContextMenuItemTile(item: entry, onSelected: onItemTap),
              },
          ],
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
  OverlayEntry? _submenuEntry;
  final _key = GlobalKey();

  void _openSubmenu() {
    if (widget.item.submenu == null || _submenuEntry != null) return;
    final box = _key.currentContext!.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(box.size.width, 0));
    _submenuEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: topLeft.dx + 4,
        top: topLeft.dy - 4,
        child: _ContextMenuSurface(items: widget.item.submenu!, radius: kRadius, onItemTap: widget.onSelected),
      ),
    );
    Overlay.of(context).insert(_submenuEntry!);
  }

  void _closeSubmenu() {
    _submenuEntry?.remove();
    _submenuEntry = null;
  }

  @override
  void dispose() {
    _submenuEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destructive = widget.item.destructive;
    return MouseRegion(
      key: _key,
      onEnter: (_) {
        setState(() => _hovered = true);
        _openSubmenu();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        if (widget.item.submenu == null) _closeSubmenu();
      },
      child: GestureDetector(
        onTap: widget.item.submenu != null
            ? null
            : () {
                widget.item.onTap?.call();
                widget.onSelected();
              },
        child: AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? (destructive ? _Tokens.destructive.withValues(alpha: 0.2) : _Tokens.accent)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius * 0.6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: destructive ? _Tokens.destructive : (_hovered ? _Tokens.accentForeground : _Tokens.foreground),
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.item.shortcut != null)
                Text(widget.item.shortcut!, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 12)),
              if (widget.item.submenu != null)
                const Icon(Icons.chevron_right, size: 16, color: _Tokens.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast — sonner.tsx только темизирует внешний npm-пакет `sonner`, логики
// стекинга/анимации в самом shadcn-ui/ui нет (см. docs/shadcn/PLAN.md).
// Портируем карточку (bg=popover, border, radius=var(--radius) напрямую,
// т.е. БЕЗ *0.8 — так задано в sonner.tsx через --border-radius) и вход
// снизу вверх. Стекинг — простой список, без offset/scale эффектов
// настоящего sonner.
// ---------------------------------------------------------------------------

class PortToastData {
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  PortToastData({required this.title, this.description, this.actionLabel, this.onAction});
}

class PortToastHost extends StatefulWidget {
  final Widget child;
  const PortToastHost({super.key, required this.child});

  static void show(BuildContext context, PortToastData data) =>
      context.findAncestorStateOfType<_PortToastHostState>()!.show(data);

  @override
  State<PortToastHost> createState() => _PortToastHostState();
}

class _PortToastHostState extends State<PortToastHost> {
  final List<_ToastEntry> _toasts = [];

  void show(PortToastData data) {
    final entry = _ToastEntry(data);
    setState(() => _toasts.add(entry));
    entry.timer = Timer(const Duration(seconds: 4), () => _remove(entry));
  }

  void _remove(_ToastEntry entry) {
    entry.timer?.cancel();
    if (mounted) setState(() => _toasts.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in _toasts)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ToastCard(data: entry.data, onClose: () => _remove(entry)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastEntry {
  final PortToastData data;
  Timer? timer;
  _ToastEntry(this.data);
}

class _ToastCard extends StatefulWidget {
  final PortToastData data;
  final VoidCallback onClose;
  const _ToastCard({required this.data, required this.onClose});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: _kEase);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(curved),
      child: FadeTransition(
        opacity: curved,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Tokens.popover,
            borderRadius: BorderRadius.circular(kRadius), // var(--radius) напрямую
            border: Border.all(color: _Tokens.border),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.data.title, style: const TextStyle(color: _Tokens.popoverForeground, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (widget.data.description != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.data.description!, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              if (widget.data.actionLabel != null) ...[
                const SizedBox(width: 12),
                PortButton(label: widget.data.actionLabel!, radius: kRadius, variant: PortButtonVariant.secondary, onPressed: widget.data.onAction),
              ],
              const SizedBox(width: 8),
              PortIconButton(icon: Icons.close, radius: kRadius, variant: PortButtonVariant.ghost, size: 24, onPressed: widget.onClose),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card — card.tsx. rounded-xl(=radius*1.4) border bg-card py-6 shadow-sm,
// секции просто px-6 без своего фона.
// ---------------------------------------------------------------------------

class PortCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget? content;
  final Widget? footer;
  final double radius;

  const PortCard({super.key, required this.title, required this.description, this.content, this.footer, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Tokens.card,
        borderRadius: BorderRadius.circular(radius * 1.4),
        border: Border.all(color: _Tokens.border),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: _Tokens.foreground, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 14)),
              ],
            ),
          ),
          if (content != null) ...[
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: content!),
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: footer!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty — empty.tsx. rounded-lg(=radius*1.0) border-dashed, media-icon
// size-10 rounded-lg bg-muted, title + description + content(кнопки).
// ---------------------------------------------------------------------------

class PortEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? actions;
  final double radius;

  const PortEmpty({super.key, required this.icon, required this.title, required this.description, this.actions, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _Tokens.border, style: BorderStyle.solid), // Flutter не умеет border-dashed нативно
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _Tokens.muted, borderRadius: BorderRadius.circular(radius)),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: _Tokens.foreground),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: _Tokens.foreground, fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 14, height: 1.4)),
          if (actions != null) ...[const SizedBox(height: 16), actions!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playground page
// ---------------------------------------------------------------------------

class ShadcnPlaygroundPage extends StatefulWidget {
  const ShadcnPlaygroundPage({super.key});

  @override
  State<ShadcnPlaygroundPage> createState() => _ShadcnPlaygroundPageState();
}

class _ShadcnPlaygroundPageState extends State<ShadcnPlaygroundPage> {
  // Слайдер остаётся для подбора/сверки — стартует с уже подобранного
  // kRadius, а не с дефолта shadcn (10px).
  double _radius = kRadius;
  String _fruit = 'Banana';
  bool _switchA = false;
  bool _switchB = true;

  @override
  Widget build(BuildContext context) {
    return PortToastHost(
      child: ColoredBox(
        color: _Tokens.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _Tokens.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _Tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('shadcn port test', style: TextStyle(color: _Tokens.foreground, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('--radius: ', style: TextStyle(color: _Tokens.mutedForeground, fontSize: 12)),
                      Text('${_radius.toStringAsFixed(0)}px', style: const TextStyle(color: _Tokens.foreground, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _radius,
                          min: 0,
                          max: 24,
                          activeColor: _Tokens.primary,
                          inactiveColor: _Tokens.secondary,
                          onChanged: (v) => setState(() => _radius = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _Section('Button'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    PortButton(label: 'Button', radius: _radius, onPressed: () {}),
                    PortButton(label: 'Secondary', radius: _radius, variant: PortButtonVariant.secondary, onPressed: () {}),
                    PortButton(label: 'Outline', radius: _radius, variant: PortButtonVariant.outline, onPressed: () {}),
                    PortButton(label: 'Ghost', radius: _radius, variant: PortButtonVariant.ghost, onPressed: () {}),
                    PortButton(label: 'Destructive', radius: _radius, variant: PortButtonVariant.destructive, onPressed: () {}),
                  ]),

                  _Section('IconButton'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    PortIconButton(icon: Icons.add, radius: _radius, variant: PortButtonVariant.primary, onPressed: () {}),
                    PortIconButton(icon: Icons.add, radius: _radius, variant: PortButtonVariant.secondary, onPressed: () {}),
                    PortIconButton(icon: Icons.add, radius: _radius, variant: PortButtonVariant.outline, onPressed: () {}),
                    PortIconButton(icon: Icons.add, radius: _radius, variant: PortButtonVariant.ghost, onPressed: () {}),
                    PortIconButton(icon: Icons.close, radius: _radius, variant: PortButtonVariant.destructive, onPressed: () {}),
                  ]),

                  _Section('Input'),
                  PortInput(placeholder: 'Name', radius: _radius),

                  _Section('Badge'),
                  Wrap(spacing: 8, runSpacing: 8, children: const [
                    PortBadge(label: 'Badge'),
                    PortBadge(label: 'Secondary', variant: PortBadgeVariant.secondary),
                    PortBadge(label: 'Outline', variant: PortBadgeVariant.outline),
                  ]),

                  _Section('Switch'),
                  Row(children: [
                    PortSwitch(value: _switchA, onChanged: (v) => setState(() => _switchA = v)),
                    const SizedBox(width: 16),
                    PortSwitch(value: _switchB, onChanged: (v) => setState(() => _switchB = v)),
                  ]),

                  _Section('Select'),
                  PortSelect(
                    options: const ['Apple', 'Banana', 'Blueberry', 'Grapes', 'Pineapple'],
                    value: _fruit,
                    groupLabel: 'Fruits',
                    radius: _radius,
                    onChanged: (v) => setState(() => _fruit = v),
                  ),

                  _Section('ContextMenu (правый клик)'),
                  PortContextMenuRegion(
                    radius: _radius,
                    items: [
                      const PortContextMenuItem(label: 'Back', shortcut: '⌘['),
                      const PortContextMenuItem(label: 'Reload', shortcut: '⌘R'),
                      PortContextMenuItem(label: 'More Tools', submenu: [
                        const PortContextMenuItem(label: 'Save Page…'),
                        const PortContextMenuItem(label: 'Create Shortcut…'),
                      ]),
                      const PortContextMenuSeparator(),
                      const PortContextMenuItem(label: 'Delete', destructive: true),
                    ],
                    child: Container(
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: _Tokens.border),
                        borderRadius: BorderRadius.circular(_radius * 0.8),
                      ),
                      child: const Text('Right click here', style: TextStyle(color: _Tokens.mutedForeground, fontSize: 13)),
                    ),
                  ),

                  _Section('Dialog / Alert Dialog / Sheet / Toast'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    PortButton(
                      label: 'Open Dialog',
                      radius: _radius,
                      variant: PortButtonVariant.outline,
                      onPressed: () => showPortDialog(
                        context: context,
                        builder: (context) => PortDialogChrome(
                          radius: _radius,
                          title: 'Edit profile',
                          description: "Make changes to your profile here. Click save when you're done.",
                          content: Column(children: [
                            PortInput(placeholder: 'Pedro Duarte', radius: _radius),
                            const SizedBox(height: 8),
                            PortInput(placeholder: '@peduarte', radius: _radius),
                          ]),
                          actions: [
                            PortButton(label: 'Cancel', radius: _radius, variant: PortButtonVariant.outline, onPressed: () => Navigator.of(context).pop()),
                            PortButton(label: 'Save changes', radius: _radius, onPressed: () => Navigator.of(context).pop()),
                          ],
                        ),
                      ),
                    ),
                    PortButton(
                      label: 'Open Alert',
                      radius: _radius,
                      variant: PortButtonVariant.outline,
                      onPressed: () => showPortDialog(
                        context: context,
                        builder: (context) => PortDialogChrome(
                          radius: _radius,
                          showCloseButton: false,
                          title: 'Are you absolutely sure?',
                          description: 'This action cannot be undone. This will permanently delete your account from our servers.',
                          actions: [
                            PortButton(label: 'Cancel', radius: _radius, variant: PortButtonVariant.outline, onPressed: () => Navigator.of(context).pop()),
                            PortButton(label: 'Continue', radius: _radius, onPressed: () => Navigator.of(context).pop()),
                          ],
                        ),
                      ),
                    ),
                    PortButton(
                      label: 'Open Sheet',
                      radius: _radius,
                      variant: PortButtonVariant.outline,
                      onPressed: () => showPortSheet(
                        context: context,
                        side: PortSheetSide.right,
                        builder: (context) => const PortSheetChrome(
                          title: 'Edit profile',
                          description: "Make changes to your profile here. Click save when you're done.",
                        ),
                      ),
                    ),
                    Builder(builder: (context) {
                      return PortButton(
                        label: 'Show Toast',
                        radius: _radius,
                        variant: PortButtonVariant.outline,
                        onPressed: () => PortToastHost.show(
                          context,
                          PortToastData(title: 'Event created', description: 'Sunday, December 3 at 9:00 AM', actionLabel: 'Undo', onAction: () {}),
                        ),
                      );
                    }),
                  ]),

                  _Section('Card'),
                  PortCard(
                    radius: _radius,
                    title: 'Login to your account',
                    description: 'Enter your email below to login to your account',
                    content: Column(children: [
                      PortInput(placeholder: 'm@example.com', radius: _radius),
                      const SizedBox(height: 8),
                      PortInput(placeholder: 'Password', radius: _radius),
                    ]),
                    footer: Column(children: [
                      PortButton(label: 'Login', radius: _radius, onPressed: () {}),
                      const SizedBox(height: 8),
                      PortButton(label: 'Login with Google', radius: _radius, variant: PortButtonVariant.secondary, onPressed: () {}),
                    ]),
                  ),

                  _Section('Empty'),
                  PortEmpty(
                    radius: _radius,
                    icon: Icons.folder_outlined,
                    title: 'No Projects Yet',
                    description: "You haven't created any projects yet.\nGet started by creating your first project.",
                    actions: Wrap(spacing: 8, children: [
                      PortButton(label: 'Create Project', radius: _radius, onPressed: () {}),
                      PortButton(label: 'Import Project', radius: _radius, variant: PortButtonVariant.outline, onPressed: () {}),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(label, style: const TextStyle(color: _Tokens.mutedForeground, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}
