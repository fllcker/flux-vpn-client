part of 'port_ui.dart';

/// Dialog / Alert Dialog — dialog.tsx / alert-dialog.tsx. Overlay fade,
/// content rounded-lg(=kRadius) border bg-background p-6 shadow-lg,
/// zoom-in-95+fade-in-0, duration-200.
class PortDialog extends StatelessWidget {
  final Widget title;
  final Widget? description;
  final Widget? child;
  final List<Widget> actions;
  final bool showCloseButton;

  const PortDialog({
    super.key,
    required this.title,
    this.description,
    this.child,
    this.actions = const [],
  }) : showCloseButton = true;

  const PortDialog.alert({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
  }) : child = null,
       showCloseButton = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24), // p-6
        decoration: BoxDecoration(
          color: PortColors.background,
          borderRadius: BorderRadius.circular(kRadius), // rounded-lg = radius*1.0
          border: Border.all(color: PortColors.border),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(style: PortText.large, child: title),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  DefaultTextStyle.merge(style: PortText.muted, child: description!),
                ],
                if (child != null) ...[const SizedBox(height: 16), child!],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
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
                      child: const Icon(Icons.close, size: 16, color: PortColors.foreground),
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

Future<T?> showPortDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dialog',
    barrierDismissible: true, // Radix Dialog по умолчанию закрывается кликом вне контента
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
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
