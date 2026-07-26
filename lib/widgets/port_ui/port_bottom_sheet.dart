part of 'port_ui.dart';

/// Выезжающий снизу лист — мобильная замена постоянно видимой боковой
/// панели на узких окнах (см. ROADMAP.md, трек 16: список серверов
/// становится этим листом вместо `ServerListPanel`, когда ширина окна ниже
/// [kMobileBreakpoint]). Анимация/барьер — тот же паттерн, что и
/// `showPortDialog` (`_kEase`, `Colors.black.withValues(alpha: 0.5)`), но
/// контент прижат к низу и растёт вверх вместо возникновения по центру.
Future<T?> showPortBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFraction = 0.75,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'bottom-sheet',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
        ),
        child: _DraggableSheetBody(
          child: SafeArea(top: false, child: builder(context)),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: _kEase, reverseCurve: _kEase);
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

/// Раньше лист закрывался только тапом на затемнение — на десктопе (мышь)
/// это не бросалось в глаза, но на телефоне палец инстинктивно тянет лист
/// вниз, а жеста не было вовсе: `Container` без `GestureDetector`. Ручка
/// сверху — обычная mobile-конвенция, показывает, что лист можно тащить.
class _DraggableSheetBody extends StatefulWidget {
  final Widget child;
  const _DraggableSheetBody({required this.child});

  @override
  State<_DraggableSheetBody> createState() => _DraggableSheetBodyState();
}

class _DraggableSheetBodyState extends State<_DraggableSheetBody> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final height = context.size?.height ?? 0;
    // Порог — треть высоты листа или заметная скорость свайпа вниз, тот же
    // критерий, что у стандартных modal bottom sheet в других приложениях.
    final shouldDismiss =
        _dragOffset > height / 3 ||
        details.primaryVelocity != null && details.primaryVelocity! > 700;
    if (shouldDismiss) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  // Раньше пробовали ловить "список докрутился до верха и палец тянет
  // дальше" через NotificationListener<ScrollNotification> +
  // BouncingScrollPhysics (чтобы получать OverscrollNotification) — на
  // практике списки в этом приложении почти всегда длиннее, чем видимая
  // область листа, и палец успевает просто проскроллить контент, ни разу
  // не долетев до состояния overscroll за один свайп. Оставили только
  // ручку — она честно работает, а тащить весь список целиком лишний
  // риск сломать десктопную ServerListPanel, использующую тот же виджет.
  static const _grabStripHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _dragOffset == 0 ? const Duration(milliseconds: 150) : Duration.zero,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: PortColors.background,
        border: Border(
          top: BorderSide(color: PortColors.border),
          left: BorderSide(color: PortColors.border),
          right: BorderSide(color: PortColors.border),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(kRadius),
          topRight: Radius.circular(kRadius),
        ),
      ),
      // Column, не Stack — контент (ServerListContent и т.п.) сам может быть
      // скроллящимся списком, и если жест перетаскивания листа вешать на всю
      // эту область, GestureDetector конкурирует за вертикальный драг с
      // внутренним Scrollable и обычно проигрывает: тащить палец можно было
      // только за 4px видимой ручки, а остальная область просто скроллила
      // список, не сдвигая лист. Поэтому область перетаскивания — только
      // отдельная полоска сверху, до начала скроллящегося контента.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: const SizedBox(
              height: _grabStripHeight,
              width: double.infinity,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _GrabHandle(),
                ),
              ),
            ),
          ),
          Flexible(child: widget.child),
        ],
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: PortColors.mutedForeground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
