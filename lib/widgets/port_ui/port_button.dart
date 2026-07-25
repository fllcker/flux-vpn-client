part of 'port_ui.dart';

/// Button / IconButton — button.tsx. variant и size ортогональны в
/// исходнике: IconButton не отдельный компонент, а Button с size="icon".
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
      bg = hovered ? Color.lerp(PortColors.background, PortColors.primary, 0.9)! : PortColors.primary;
      fg = PortColors.primaryForeground;
      break;
    case PortButtonVariant.secondary:
      // bg-secondary text-secondary-foreground hover:bg-secondary/80
      bg = hovered ? Color.lerp(PortColors.background, PortColors.secondary, 0.8)! : PortColors.secondary;
      fg = PortColors.secondaryForeground;
      break;
    case PortButtonVariant.outline:
      // border bg-background shadow-xs hover:bg-accent
      // dark:border-input dark:bg-input/30 dark:hover:bg-input/50
      final overlayAlpha = hovered ? 0.15 * 0.50 : 0.15 * 0.30;
      bg = Color.lerp(PortColors.background, Colors.white, overlayAlpha)!;
      border = PortColors.inputBorder;
      fg = PortColors.foreground;
      shadow = const [
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 1), blurRadius: 2),
      ];
      break;
    case PortButtonVariant.ghost:
      // hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50
      bg = hovered ? Color.lerp(PortColors.background, PortColors.accent, 0.5)! : Colors.transparent;
      fg = PortColors.foreground;
      break;
    case PortButtonVariant.destructive:
      // bg-destructive text-white hover:bg-destructive/90 dark:bg-destructive/60
      // (см. docs/shadcn/PLAN.md, "Известные ограничения" — hover в dark не
      // проверен вживую, каскад hover+dark неоднозначен без реальной сборки)
      bg = Color.lerp(PortColors.background, PortColors.destructive, hovered ? 0.5 : 0.6)!;
      fg = Colors.white;
      break;
  }

  return _ButtonVisual(bg: bg, border: border, fg: fg, shadow: shadow);
}

BoxDecoration _focusRingDecoration(_ButtonVisual v, double radius, bool focused) {
  var border = v.border;
  var shadow = v.shadow;
  if (focused) {
    border = PortColors.ring;
    shadow = [...shadow, BoxShadow(color: PortColors.ring.withValues(alpha: 0.5), spreadRadius: 3)];
  }
  return BoxDecoration(
    color: v.bg,
    borderRadius: BorderRadius.circular(radius),
    border: border != null ? Border.all(color: border) : null,
    boxShadow: shadow,
  );
}

class PortButton extends StatelessWidget {
  final Widget child;
  final Widget? leading;
  final PortButtonVariant variant;
  final VoidCallback? onPressed;

  const PortButton({super.key, required this.child, this.leading, this.onPressed})
    : variant = PortButtonVariant.primary;
  const PortButton.secondary({super.key, required this.child, this.leading, this.onPressed})
    : variant = PortButtonVariant.secondary;
  const PortButton.outline({super.key, required this.child, this.leading, this.onPressed})
    : variant = PortButtonVariant.outline;
  const PortButton.ghost({super.key, required this.child, this.leading, this.onPressed})
    : variant = PortButtonVariant.ghost;
  const PortButton.destructive({super.key, required this.child, this.leading, this.onPressed})
    : variant = PortButtonVariant.destructive;

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
          decoration: _focusRingDecoration(v, kRadius * 0.8, focused),
          // Row(mainAxisSize: min) вместо Container.alignment — у Container
          // без явной width, но с alignment, RenderPositionedBox
          // разворачивается на весь bounded простор (капкан Flutter), а нам
          // нужен inline-flex, сжатый по содержимому.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                IconTheme.merge(data: IconThemeData(color: v.fg, size: 14), child: leading!),
                const SizedBox(width: 8),
              ],
              AnimatedDefaultTextStyle(
                duration: _kDuration,
                curve: _kEase,
                style: TextStyle(color: v.fg, fontSize: 14, fontWeight: FontWeight.w500, height: 1),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class PortIconButton extends StatelessWidget {
  final Widget icon;
  final PortButtonVariant variant;
  final double size; // size-9 по умолчанию (36)
  final VoidCallback? onPressed;

  const PortIconButton({super.key, required this.icon, this.size = 36, this.onPressed})
    : variant = PortButtonVariant.primary;
  const PortIconButton.secondary({super.key, required this.icon, this.size = 36, this.onPressed})
    : variant = PortButtonVariant.secondary;
  const PortIconButton.outline({super.key, required this.icon, this.size = 36, this.onPressed})
    : variant = PortButtonVariant.outline;
  const PortIconButton.ghost({super.key, required this.icon, this.size = 36, this.onPressed})
    : variant = PortButtonVariant.ghost;
  const PortIconButton.destructive({super.key, required this.icon, this.size = 36, this.onPressed})
    : variant = PortButtonVariant.destructive;

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
          decoration: _focusRingDecoration(v, kRadius * 0.8, focused),
          alignment: Alignment.center,
          // Иконка почти всегда уже задаёт себе явные size/color на месте
          // вызова — IconTheme работает только как fallback (Icon.color ??
          // IconTheme.of(context).color), не перетирая явные значения.
          child: IconTheme.merge(data: IconThemeData(color: v.fg, size: 16), child: icon),
        );
      },
    );
  }
}
