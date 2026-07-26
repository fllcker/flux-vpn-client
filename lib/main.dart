import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_title_bar.dart';
import 'app/deep_link.dart';
import 'app/single_instance.dart';
import 'app/tray.dart';
import 'core_abstraction/app_settings.dart';
import 'core_abstraction/app_settings_provider.dart';
import 'features/connection/connection_screen.dart';
import 'features/servers/clipboard_import_hotkey.dart';
import 'features/servers/import_subscription_sheet.dart';
import 'features/settings/settings_page.dart';
import 'l10n/app_locale.dart';
import 'widgets/port_ui/port_ui.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  // Windows передаёт зарегистрированный `flux://...` URL как аргумент
  // командной строки — как при первом запуске, так и при повторном клике по
  // ссылке, пока приложение уже открыто (тогда ОС просто стартует второй
  // процесс, который должен переслать ссылку первому и сразу выйти).
  final initialDeepLink = extractFluxDeepLinkFromArgs(args);
  final instance = await acquireSingleInstance(deepLink: initialDeepLink);
  if (instance is SecondaryInstance) {
    exit(0);
  }
  final incomingDeepLinks = (instance as PrimaryInstance).incomingDeepLinks;
  // Автозапуск при старте Windows передаёт этот флаг (см.
  // `windows_autostart.dart`), чтобы не мозолить окном при входе в систему —
  // окно остаётся скрытым, доступно через иконку в трее.
  final startMinimized = args.contains('--minimized');

  WidgetsFlutterBinding.ensureInitialized();

  // window_manager/tray_manager have no Android implementation — calling
  // them there throws MissingPluginException. Was unguarded here (unlike
  // tray.dart/deep_link.dart, which already self-guard), so on Android the
  // unhandled exception from ensureInitialized() aborted main() before
  // runApp() ever ran — black screen, nothing else wrong.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    registerFluxUriProtocolIfNeeded();
  }

  // Стартовый size — дефолт для десктопа, не трогаем. minimumSize снижен
  // против прежних 760×480, чтобы окно можно было вручную ужать до
  // мобильных пропорций и проверить адаптивную раскладку прямо на Windows
  // resize'ом — см. ROADMAP.md, трек 16.
  const windowOptions = WindowOptions(
    size: Size(960, 620),
    minimumSize: Size(320, 480),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  // Явный контейнер (вместо неявного из голого ProviderScope) — обработчики
  // кликов по иконке трея (`tray.dart`) живут вне дерева виджетов и не
  // могут получить WidgetRef, но могут читать/писать через этот же
  // контейнер.
  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: FluxApp(
        navigatorKey: _navigatorKey,
        initialDeepLink: initialDeepLink,
        incomingDeepLinks: incomingDeepLinks,
      ),
    ),
  );

  if (!Platform.isWindows) return;

  // Закрытие окна (крестик/Alt+F4) сворачивает в трей вместо выхода — сам
  // перехват в `_FluxAppState.onWindowClose` (main.dart, WindowListener).
  await windowManager.setPreventClose(true);
  await FluxTray(container).init();

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await _warmUpOverlays();
    if (startMinimized) return;
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Первый показ любого PortDialog/оверлея заметно лагает (шрифты/лэйаут
/// компилируются впервые для этого поддерева виджетов) — второй и
/// последующие уже гладкие. Прогреваем это один раз здесь, пока окно ещё
/// не показано пользователю, чтобы он не видел этот лаг на реальном
/// диалоге импорта подписки.
Future<void> _warmUpOverlays() async {
  await WidgetsBinding.instance.endOfFrame;
  final context = _navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  showPortDialog(
    context: context,
    builder: (_) => const ImportSubscriptionSheet(),
  );
  await WidgetsBinding.instance.endOfFrame;
  final navigator = _navigatorKey.currentState;
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}

class FluxApp extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String? initialDeepLink;
  final Stream<String> incomingDeepLinks;

  const FluxApp({
    super.key,
    required this.navigatorKey,
    required this.incomingDeepLinks,
    this.initialDeepLink,
  });

  @override
  ConsumerState<FluxApp> createState() => _FluxAppState();
}

class _FluxAppState extends ConsumerState<FluxApp>
    with WindowListener, WidgetsBindingObserver {
  StreamSubscription<String>? _deepLinkSub;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _deepLinkSub = widget.incomingDeepLinks.listen(_handleIncomingDeepLink);
    if (widget.initialDeepLink case final link?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openAddDialogForDeepLink(link),
      );
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  // Реагируем на смену темы/языка ОС на лету — только для
  // AppThemeMode.system/AppLanguage.system, см. build(). Без rebuild здесь
  // изменение системной темы/локали подхватилось бы только при следующей
  // перестройке дерева по другой причине.
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  // Срабатывает только когда `windowManager.setPreventClose(true)` (см.
  // main.dart) — обычное закрытие ОС не завершает событийный цикл, вместо
  // этого прилетает сюда. Полный выход — только через пункт "Выход" в трее
  // (`tray.dart`), который сначала снимает preventClose.
  @override
  void onWindowClose() => windowManager.hide();

  Future<void> _handleIncomingDeepLink(String link) async {
    if (Platform.isWindows) {
      await windowManager.show();
      await windowManager.focus();
    }
    if (link.isEmpty) return;
    _openAddDialogForDeepLink(link);
  }

  void _openAddDialogForDeepLink(String link) {
    final parsed = parseFluxDeepLink(link);
    if (parsed == null) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    showAddServerDialog(context, initialLink: parsed);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    // Присваивается синхронно перед сборкой поддерева — PortColors/S читают
    // эти статики каждый вызов геттера, отдельный InheritedWidget не нужен
    // (см. widgets/port_ui/port_theme.dart, l10n/app_locale.dart).
    //
    // Светлая тема временно залочена на Dark независимо от settings.themeMode
    // (селектор в настройках тоже залочен, см. settings_page.dart) — светлая
    // палитра требует визуальной доводки (см. ROADMAP.md, трек 18), пока не
    // готова. Раскомментировать switch ниже, когда светлую тему доведут.
    PortBrightness.current = Brightness.dark;
    // PortBrightness.current = switch (settings.themeMode) {
    //   AppThemeMode.light => Brightness.light,
    //   AppThemeMode.dark => Brightness.dark,
    //   AppThemeMode.system => View.of(context).platformDispatcher.platformBrightness,
    // };
    AppLocale.effective = switch (settings.language) {
      AppLanguage.ru => AppLanguage.ru,
      AppLanguage.en => AppLanguage.en,
      AppLanguage.system =>
        View.of(context).platformDispatcher.locale.languageCode == 'ru'
            ? AppLanguage.ru
            : AppLanguage.en,
    };

    return PortApp(
      navigatorKey: widget.navigatorKey,
      title: 'Flux',
      home: ClipboardImportHotkey(
        // Settings — не отдельный Navigator-route, а просто переключение
        // `_settingsOpen` в этом же build (см. комментарий у AppTitleBar
        // ниже) — поэтому системная кнопка/жест "назад" на Android об это
        // ничего не знали и не закрывали Settings вовсе (обычное поведение
        // WidgetsApp — попытаться вытолкнуть route, а у единственного route
        // "home" вытолкнуть нечего). PopScope перехватывает именно этот
        // случай: пока Settings открыты, не даём поп-у уйти дальше и вместо
        // этого закрываем Settings сами — на десктопе не нужно (там нет ни
        // аппаратной кнопки, ни жеста back).
        child: PopScope(
          canPop: !(Platform.isAndroid && _settingsOpen),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) setState(() => _settingsOpen = false);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Кастомный тайтлбар (drag-area, minimize/maximize/close) имеет
              // смысл только для окна с рамкой — на Android об это спотыкались
              // (см. ROADMAP.md, трек 19, Phase 4): вместо системной шторки
              // сверху висела десктопная полоска с логотипом. SettingsPage
              // сама себе шапка с кнопкой "назад" (см. settings_page.dart),
              // так что тайтлбар не нужен и как единственный путь туда —
              // на мобильной раскладке ConnectionScreen сама даёт плавающую
              // кнопку настроек (`onOpenSettings`).
              if (!Platform.isAndroid)
                AppTitleBar(
                  settingsOpen: _settingsOpen,
                  onToggleSettings: () =>
                      setState(() => _settingsOpen = !_settingsOpen),
                ),
              Expanded(
                child: _settingsOpen
                    ? SettingsPage(
                        onBack: () => setState(() => _settingsOpen = false),
                      )
                    : ConnectionScreen(
                        onOpenSettings: () =>
                            setState(() => _settingsOpen = true),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
