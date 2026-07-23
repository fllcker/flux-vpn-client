import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fake_server.dart';
import 'selected_server_provider.dart';
import 'server_row.dart';

class ServerListPanel extends ConsumerWidget {
  const ServerListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final selectedId = ref.watch(selectedServerIdProvider);

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text('Серверы', style: theme.textTheme.h4),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: fakeServers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final server = fakeServers[index];
                return ServerRow(
                  server: server,
                  selected: server.id == selectedId,
                  onTap: () =>
                      ref.read(selectedServerIdProvider.notifier).select(server.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
