import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fake_server.dart';

class ServerRow extends StatefulWidget {
  final FakeServer server;
  final bool selected;
  final VoidCallback onTap;

  const ServerRow({
    super.key,
    required this.server,
    required this.selected,
    required this.onTap,
  });

  @override
  State<ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<ServerRow> {
  bool _hovered = false;

  Color _pingColor(ShadColorScheme scheme, int pingMs) {
    if (pingMs < 80) return const Color(0xFF4ADE80);
    if (pingMs < 160) return const Color(0xFFFACC15);
    return const Color(0xFFF87171);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final background = widget.selected
        ? scheme.accent
        : _hovered
        ? scheme.accent.withValues(alpha: 0.5)
        : const Color(0x00000000);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? scheme.primary
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(widget.server.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.server.name,
                  style: theme.textTheme.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: _pingColor(scheme, widget.server.pingMs),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                '${widget.server.pingMs} мс',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
