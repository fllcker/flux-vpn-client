part of 'port_ui.dart';

/// :root .dark, base color "neutral" — https://ui.shadcn.com. OKLCH-токены
/// из apps/v4/registry/new-york-v4, пересчитанные в sRGB вручную (OKLab ->
/// linear -> gamma). Тёмные значения ниже — не трогать, светлые — тот же
/// источник (:root, не .dark), пересчитанные тем же способом; `accent`
/// светлой темы — единственное исключение, взято чуть темнее `muted`/
/// `secondary` по аналогии с тёмной темой (там `accent` тоже заметно темнее
/// `secondary`/`muted`, а не совпадает с ними, как в оригинальном шаблоне).
///
/// Выбор темы читается из [PortBrightness.current] (см. `port_theme.dart`)
/// каждым геттером заново — react на смену темы без `Theme.of(context)`.
abstract final class PortColors {
  static bool get _isLight => PortBrightness.current == Brightness.light;

  static Color get background =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0A0A0A);
  static Color get foreground =>
      _isLight ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
  static Color get card => _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF171717);
  static Color get popover => card;
  static Color get popoverForeground => foreground;
  static Color get primary =>
      _isLight ? const Color(0xFF171717) : const Color(0xFFE5E5E5);
  static Color get primaryForeground =>
      _isLight ? const Color(0xFFFAFAFA) : const Color(0xFF171717);
  static Color get secondary =>
      _isLight ? const Color(0xFFF5F5F5) : const Color(0xFF262626);
  static Color get secondaryForeground =>
      _isLight ? const Color(0xFF171717) : const Color(0xFFFAFAFA);
  static Color get muted => _isLight ? const Color(0xFFF5F5F5) : const Color(0xFF262626);
  static Color get mutedForeground =>
      _isLight ? const Color(0xFF737373) : const Color(0xFFA1A1A1);
  static Color get accent => _isLight ? const Color(0xFFE0E0E0) : const Color(0xFF404040);
  static Color get accentForeground =>
      _isLight ? const Color(0xFF171717) : const Color(0xFFFAFAFA);
  static Color get destructive =>
      _isLight ? const Color(0xFFDC2626) : const Color(0xFFFF6466);
  static Color get ring => _isLight ? const Color(0xFFA1A1A1) : const Color(0xFF737373);

  // --border/--input в CSS хранятся уже С альфой (oklch(1 0 0 / 10%) и
  // /15%). Модификатор Tailwind bg-input/30 делает color-mix(input 30%,
  // transparent) -> итоговая альфа = 0.15 * 0.30, не 30% сама по себе.
  // В светлой теме та же логика, но альфа накладывается на чёрный, а не
  // белый — граница должна быть чуть темнее фона, а не чуть светлее.
  static Color get border => _isLight
      ? const Color.fromRGBO(0, 0, 0, 0.10)
      : const Color.fromRGBO(255, 255, 255, 0.10);
  static Color get inputBorder => _isLight
      ? const Color.fromRGBO(0, 0, 0, 0.15)
      : const Color.fromRGBO(255, 255, 255, 0.15);
}

/// Типографика shadcn/ui (стандартная документированная шкала —
/// text-xl/lg/base/sm font-semibold/medium tracking-tight и т.п.), не
/// специфична под этот проект. Используем Inter тем же способом, что и
/// раньше через ShadTextTheme.fromGoogleFont(GoogleFonts.inter).
abstract final class PortText {
  static TextStyle get h4 => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: PortColors.foreground,
  );
  static TextStyle get large => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: PortColors.foreground,
  );
  static TextStyle get p => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 28 / 16,
    color: PortColors.foreground,
  );
  static TextStyle get small => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1,
    color: PortColors.foreground,
  );
  static TextStyle get muted => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: PortColors.mutedForeground,
  );
}

const _kEase = Cubic(0.4, 0, 0.2, 1); // tailwind default transition easing
const _kDuration = Duration(milliseconds: 150); // tailwind default duration

/// --radius (px), см. docs/shadcn/PLAN.md — подобрано и подтверждено
/// визуальной сверкой со скриншотами shadcn.com. rounded-md = kRadius*0.8,
/// rounded-lg = kRadius*1.0, rounded-sm = kRadius*0.6.
const kRadius = 24.0;

// ---------------------------------------------------------------------------
// Общая интерактивная обвязка (hover/focus/press), общая для Button/
// IconButton/Select-триггера — избегаем дублирования трёх setState-флагов в
// каждом виджете.
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

/// Fade+zoom-95 подложка попапов (Select/ContextMenu content) —
/// data-[state=open]:zoom-in-95 data-[state=open]:fade-in-0.
class _PopoverSurface extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Alignment origin;

  const _PopoverSurface({
    required this.animation,
    required this.child,
    this.origin = Alignment.topCenter,
  });

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
