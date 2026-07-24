import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_title_bar.dart';
import 'app/deep_link.dart';
import 'app/single_instance.dart';
import 'core_abstraction/app_settings.dart';
import 'core_abstraction/app_settings_provider.dart';
import 'features/connection/connection_screen.dart';
import 'features/servers/clipboard_import_hotkey.dart';
import 'features/servers/import_subscription_sheet.dart';

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

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  registerFluxUriProtocolIfNeeded();

  const windowOptions = WindowOptions(
    size: Size(960, 620),
    minimumSize: Size(760, 480),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  runApp(
    ProviderScope(
      child: FluxApp(
        navigatorKey: _navigatorKey,
        initialDeepLink: initialDeepLink,
        incomingDeepLinks: incomingDeepLinks,
      ),
    ),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await _warmUpOverlays();
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Первый показ любого ShadDialog/оверлея заметно лагает (шрифты/лэйаут
/// компилируются впервые для этого поддерева виджетов) — второй и
/// последующие уже гладкие. Прогреваем это один раз здесь, пока окно ещё
/// не показано пользователю, чтобы он не видел этот лаг на реальном
/// диалоге импорта подписки.
Future<void> _warmUpOverlays() async {
  await WidgetsBinding.instance.endOfFrame;
  final context = _navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  showShadDialog(context: context, builder: (_) => const ImportSubscriptionSheet());
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

class _FluxAppState extends ConsumerState<FluxApp> {
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _deepLinkSub = widget.incomingDeepLinks.listen(_handleIncomingDeepLink);
    if (widget.initialDeepLink case final link?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openAddDialogForDeepLink(link),
      );
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _handleIncomingDeepLink(String link) async {
    await windowManager.show();
    await windowManager.focus();
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
    final themeMode = ref.watch(
      appSettingsProvider.select((s) => s.themeMode),
    );

    return ShadApp(
      navigatorKey: widget.navigatorKey,
      title: 'Flux',
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
        textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
        textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      ),
      home: const ClipboardImportHotkey(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [AppTitleBar(), Expanded(child: ConnectionScreen())],
        ),
      ),
    );
  }
}
