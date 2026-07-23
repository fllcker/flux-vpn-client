import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../servers/fake_server.dart';
import '../servers/selected_server_provider.dart';
import 'fake_connection_state.dart';
import 'mode_toggle.dart';

class ConnectPanel extends ConsumerWidget {
  const ConnectPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final selectedId = ref.watch(selectedServerIdProvider);
    final server = fakeServers.firstWhere((s) => s.id == selectedId);
    final mode = ref.watch(connectionModeProvider);
    final connected = ref.watch(fakeConnectedProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(server.icon, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(server.name, style: theme.textTheme.h4),
            const SizedBox(height: 4),
            Text(
              connected ? 'Подключено' : 'Отключено',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 24),
            ModeToggle(
              value: mode,
              onChanged: (m) =>
                  ref.read(connectionModeProvider.notifier).select(m),
            ),
            const SizedBox(height: 28),
            _ConnectButton(
              connected: connected,
              onPressed: () => ref.read(fakeConnectedProvider.notifier).toggle(),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: connected
                  ? const _StatsRow(key: ValueKey('stats'))
                  : const SizedBox(key: ValueKey('no-stats'), height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectButton extends StatefulWidget {
  final bool connected;
  final VoidCallback onPressed;

  const _ConnectButton({required this.connected, required this.onPressed});

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final baseColor = widget.connected
        ? const Color(0xFFF87171)
        : scheme.primary;
    final color = _hovered ? baseColor.withValues(alpha: 0.88) : baseColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(LucideIcons.power, color: scheme.primaryForeground, size: 34),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatTile(icon: LucideIcons.arrowUp, label: '1.2 MB/s'),
        SizedBox(width: 24),
        _StatTile(icon: LucideIcons.arrowDown, label: '8.4 MB/s'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.small),
      ],
    );
  }
}
