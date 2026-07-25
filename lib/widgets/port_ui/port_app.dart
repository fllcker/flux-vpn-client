part of 'port_ui.dart';

/// Замена `ShadApp` — под капотом shadcn_ui сам оборачивает `WidgetsApp`
/// (не Material/Cupertino, см. docs/shadcn/PLAN.md), так что делаем то же
/// самое напрямую: свой `WidgetsApp` + локализация (нужна `TextField`
/// внутри `PortInput`) + `PortToastHost`, обёрнутый вокруг `home`.
///
/// Тема — не через `Theme.of(context)`, а статические `PortColors`/`PortText`
/// (единственная тема — тёмная, см. заметку в port_ui.dart), поэтому здесь
/// нет параметров `theme`/`darkTheme`/`themeMode` — светлая тема будет
/// отдельной задачей, когда её допортируют.
class PortApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final String title;
  final Widget home;

  const PortApp({super.key, this.navigatorKey, this.title = '', required this.home});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      navigatorKey: navigatorKey,
      title: title,
      color: PortColors.primary,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      builder: (context, child) => DefaultTextStyle(
        style: PortText.p,
        child: PortToastHost(child: child ?? const SizedBox.shrink()),
      ),
      home: home,
    );
  }
}
