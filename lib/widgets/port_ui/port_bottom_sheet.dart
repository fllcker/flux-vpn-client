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
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: PortColors.background,
            border: Border(
              top: BorderSide(color: PortColors.border),
              left: BorderSide(color: PortColors.border),
              right: BorderSide(color: PortColors.border),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(kRadius),
              topRight: Radius.circular(kRadius),
            ),
          ),
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
