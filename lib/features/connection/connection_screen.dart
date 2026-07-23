import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../servers/server_list_panel.dart';
import 'connect_panel.dart';

/// Прототип главного экрана на фейк-данных — оценка качества портирования
/// shadcn_ui на Flutter, до подключения к реальному Core Abstraction Layer.
class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.background,
      child: const Row(
        children: [
          ServerListPanel(),
          Expanded(child: ConnectPanel()),
        ],
      ),
    );
  }
}
