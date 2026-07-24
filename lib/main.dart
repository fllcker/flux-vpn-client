import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_title_bar.dart';
import 'features/connection/connection_screen.dart';
import 'features/servers/import_subscription_sheet.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(960, 620),
    minimumSize: Size(760, 480),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  runApp(ProviderScope(child: FluxApp(navigatorKey: _navigatorKey)));

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await _warmUpOverlays();
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Первый показ любого ShadSheet/оверлея заметно лагает (шрифты/лэйаут
/// компилируются впервые для этого поддерева виджетов) — второй и
/// последующие уже гладкие. Прогреваем это один раз здесь, пока окно ещё
/// не показано пользователю, чтобы он не видел этот лаг на реальном
/// диалоге импорта подписки.
Future<void> _warmUpOverlays() async {
  await WidgetsBinding.instance.endOfFrame;
  final context = _navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  showShadSheet(context: context, builder: (_) => const ImportSubscriptionSheet());
  await WidgetsBinding.instance.endOfFrame;
  final navigator = _navigatorKey.currentState;
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}

class FluxApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const FluxApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      navigatorKey: navigatorKey,
      title: 'Flux',
      theme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      home: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [AppTitleBar(), Expanded(child: ConnectionScreen())],
      ),
    );
  }
}
