import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'connection_controller.dart';
import 'connection_state.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionControllerProvider);
    final controller = ref.read(connectionControllerProvider.notifier);
    final isBusy = state is ConnectionConnecting;
    final isConnected = state is ConnectionConnected;

    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ShadCard(
              title: const Text('VPN Client'),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadInput(
                    controller: _linkController,
                    placeholder: const Text('vless:// ссылка'),
                    enabled: !isConnected && !isBusy,
                  ),
                  const SizedBox(height: 16),
                  _StatusText(state: state),
                  const SizedBox(height: 16),
                  if (isConnected)
                    ShadButton.destructive(
                      onPressed: controller.disconnect,
                      child: const Text('Отключиться'),
                    )
                  else
                    ShadButton(
                      onPressed: isBusy
                          ? null
                          : () => controller.connect(_linkController.text),
                      child: Text(isBusy ? 'Подключение...' : 'Подключиться'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final ConnectionUiState state;
  const _StatusText({required this.state});

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      ConnectionIdle() => 'Отключено',
      ConnectionConnecting() => 'Подключение...',
      ConnectionConnected(serverName: final name) => 'Подключено: $name',
      ConnectionError(message: final message) => 'Ошибка: $message',
    };
    return Text(text, style: ShadTheme.of(context).textTheme.p);
  }
}
