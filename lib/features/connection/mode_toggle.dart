import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core_abstraction/connection_session.dart';

class ModeToggle extends StatelessWidget {
  final ConnectionMode value;
  final ValueChanged<ConnectionMode> onChanged;

  const ModeToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, ConnectionMode.proxy, 'Proxy'),
          _segment(context, ConnectionMode.tun, 'TUN'),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, ConnectionMode mode, String label) {
    final theme = ShadTheme.of(context);
    final selected = value == mode;

    return GestureDetector(
      onTap: () => onChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.background : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: theme.textTheme.small.copyWith(
            color: selected
                ? theme.colorScheme.foreground
                : theme.colorScheme.mutedForeground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
