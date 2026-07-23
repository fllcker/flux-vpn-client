import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/connection/connection_screen.dart';

void main() {
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
      home: const ConnectionScreen(),
    );
  }
}
