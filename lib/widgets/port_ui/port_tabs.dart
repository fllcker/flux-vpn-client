part of 'port_ui.dart';

/// Tabs — tabs.tsx, только TabsList/TabsTrigger (variant="default", всегда
/// horizontal): контент вкладок в этом приложении не анимируется
/// кроссфейдом как TabsContent в исходнике — секции настроек и так меняют
/// содержимое через KeyedSubtree в settings_page.dart, отдельный
/// PortTabsContent не нужен.
///
/// TabsList: inline-flex rounded-lg bg-muted p-[3px] h-9 (rounded-lg =
/// kRadius*1.0, см. port_tokens.dart). Отличия от исходника:
/// - там w-fit (сжимается по контенту, overflow отдаётся браузеру), а нам на
///   мобильной раскладке нужно 7 секций в узкую полосу — оборачиваем в
///   горизонтальный SingleChildScrollView вместо w-fit;
/// - высота (`_trackHeight`) и форма чипа увеличены/скруглены сильнее h-9 —
///   по прямому запросу юзера ("кнопки в табах оч маленькие, пусть будут
///   овальными"), не 1:1 с исходником; активный чип растягивается на всю
///   высоту трека (`CrossAxisAlignment.stretch`), а не плавает маленькой
///   плашкой посередине, как было с фиксированным `vertical: 4` паддингом.
///
/// TabsTrigger: flex-1 px-2 text-sm font-medium, text-foreground/60
/// неактивная / hover:text-foreground, активная — bg-input/30 (та же
/// alpha-формула, что и у Input/outline-Button/Select, см. их комментарии),
/// border-input, shadow-sm.
class PortTabItem<T> {
  final T value;
  final Widget? leading;
  final Widget child;
  const PortTabItem({required this.value, this.leading, required this.child});
}

class PortTabsList<T> extends StatelessWidget {
  final T value;
  final List<PortTabItem<T>> items;
  final ValueChanged<T> onChanged;

  const PortTabsList({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  static const _trackHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: _trackHeight,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PortColors.muted,
          borderRadius: BorderRadius.circular(kRadius), // pill, см. doc выше
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // Раньше чип был высотой своего паддинга (vertical: 4) и плавал
          // маленькой плашкой посреди трека — stretch тянет его на всю
          // доступную высоту (трек минус внешний паддинг).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              _PortTabTrigger<T>(
                item: item,
                selected: item.value == value,
                onTap: () => onChanged(item.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortTabTrigger<T> extends StatelessWidget {
  final PortTabItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  const _PortTabTrigger({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Interactive(
      onTap: onTap,
      // Триггеры в исходнике не "жмутся" при тапе (в отличие от Button) —
      // только меняют фон/бордер по data-[state=active].
      scaleOnPress: false,
      builder: (context, {required hovered, required focused, required pressed}) {
        final bg = selected
            ? Color.lerp(PortColors.background, Colors.white, 0.15 * 0.30)!
            : Colors.transparent;
        final fg = selected || hovered
            ? PortColors.foreground
            : PortColors.foreground.withValues(alpha: 0.6);
        return AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            // Овал по прямому запросу юзера — kRadius клэмпится Flutter'ом
            // до половины высоты чипа (тот же приём, что и у
            // OffProxyTunSelector/карточки сервера на Android).
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: selected ? PortColors.inputBorder : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 1), blurRadius: 2),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.leading != null) ...[
                IconTheme.merge(data: IconThemeData(color: fg, size: 14), child: item.leading!),
                const SizedBox(width: 6),
              ],
              AnimatedDefaultTextStyle(
                duration: _kDuration,
                curve: _kEase,
                style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500, height: 1),
                child: item.child,
              ),
            ],
          ),
        );
      },
    );
  }
}
