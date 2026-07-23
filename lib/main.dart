import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_title_bar.dart';
import 'features/connection/connection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(960, 620),
    minimumSize: Size(760, 480),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: VpnClientApp()));
}

class VpnClientApp extends StatelessWidget {
  const VpnClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'VPN Client',
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
