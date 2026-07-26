import 'package:flutter/widgets.dart';

import '../../widgets/port_ui/port_ui.dart';

enum ConnectSelection { off, proxy, tun }

/// Трёхпозиционный переключатель режима подключения (см. PLAN.md, "Режимы
/// подключения"). TUN требует прав администратора — запрос повышения прав
/// обрабатывается на уровне ConnectPanel, не здесь.
///
/// На Android отдельного Proxy-механизма нет — Off/Proxy/TUN схлопывается в
/// Off/On (см. ROADMAP.md, трек 19, Phase 4): [simplifiedOnOff] прячет
/// сегмент "Proxy" и подписывает TUN-сегмент как "On". `onChanged` тогда
/// вызывается только с [ConnectSelection.off]/[ConnectSelection.tun].
class OffProxyTunSelector extends StatelessWidget {
  final ConnectSelection value;
  final bool busy;
  final bool simplifiedOnOff;
  final ValueChanged<ConnectSelection> onChanged;

  const OffProxyTunSelector({
    super.key,
    required this.value,
    required this.busy,
    required this.onChanged,
    this.simplifiedOnOff = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PortColors.muted.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            selected: value == ConnectSelection.off,
            enabled: !busy,
            label: 'Off',
            // Два сегмента вместо трёх той же общей ширины смотрелись
            // непропорционально узко — компенсируем увеличенным паддингом
            // только здесь, десктопный трёхсегментный вид не трогаем.
            horizontalPadding: simplifiedOnOff ? 40 : 18,
            onTap: () => onChanged(ConnectSelection.off),
          ),
          if (!simplifiedOnOff)
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
            label: simplifiedOnOff ? 'On' : 'TUN',
            // "On" (Android) красится в зелёный — тот же акцент, что у
            // Proxy на десктопе, смотрится приятнее синего для простого
            // Off/On. TUN на десктопе остаётся синим, не трогаем.
            activeColor: simplifiedOnOff
                ? const Color(0xFF4ADE80)
                : const Color(0xFF60A5FA),
            horizontalPadding: simplifiedOnOff ? 40 : 18,
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
  final double horizontalPadding;
  final VoidCallback onTap;

  const _Segment({
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.activeColor,
    this.horizontalPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? PortColors.mutedForeground.withValues(alpha: 0.4)
        : selected
        ? (activeColor ?? PortColors.foreground)
        : PortColors.mutedForeground;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? PortColors.background : null,
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
            style: PortText.small.copyWith(
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
