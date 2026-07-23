import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../servers/right_panel_view.dart';
import '../servers/server_list_panel.dart';
import '../servers/subscription_info_panel.dart';
import 'connect_panel.dart';

/// Главный экран: список серверов слева, справа — карточка подключения
/// либо (если выбрана подписка в списке) информация о ней.
class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rightPanelView = ref.watch(rightPanelViewProvider);

    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.background,
      child: Row(
        children: [
          const ServerListPanel(),
          Expanded(
            child: switch (rightPanelView) {
              ConnectView() => const ConnectPanel(),
              SubscriptionInfoView(:final subscriptionId) =>
                SubscriptionInfoPanel(subscriptionId: subscriptionId),
            },
          ),
        ],
      ),
    );
  }
}
