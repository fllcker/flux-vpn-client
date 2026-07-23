import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ConnectSelection { off, proxy, tun }

/// Трёхпозиционный переключатель режима подключения (см. PLAN.md, "Режимы
/// подключения"). TUN требует прав администратора — запрос повышения прав
/// обрабатывается на уровне ConnectPanel, не здесь.
class OffProxyTunSelector extends StatelessWidget {
  final ConnectSelection value;
  final bool busy;
  final ValueChanged<ConnectSelection> onChanged;

  const OffProxyTunSelector({
    super.key,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

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
          _Segment(
            selected: value == ConnectSelection.off,
            enabled: !busy,
            label: 'Off',
            onTap: () => onChanged(ConnectSelection.off),
          ),
          _Segment(
            selected: value == ConnectSelection.proxy,
            enabled: !busy,
            label: 'Proxy',
            activeColor: const Color(0xFF4ADE80),
            onTap: () => onChanged(ConnectSelection.proxy),
          ),
          _Segment(
            selected: value == ConnectSelection.tun,
            enabled: !busy,
            label: 'TUN',
            activeColor: const Color(0xFF60A5FA),
            onTap: () => onChanged(ConnectSelection.tun),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final String label;
  final Color? activeColor;
  final VoidCallback onTap;

  const _Segment({
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final textColor = !enabled
        ? theme.colorScheme.mutedForeground.withValues(alpha: 0.4)
        : selected
        ? (activeColor ?? theme.colorScheme.foreground)
        : theme.colorScheme.mutedForeground;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
              color: textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
