import 'package:flutter/widgets.dart';

import '../../core_abstraction/home_tile_config.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'home_tiles/home_tile_card.dart';

enum ConnectSelection { off, proxy, tun }

/// Трёхпозиционный переключатель режима подключения (см. PLAN.md, "Режимы
/// подключения"). TUN требует прав администратора — запрос повышения прав
/// обрабатывается на уровне ConnectPanel, не здесь.
///
/// На Android отдельного Proxy-механизма нет — Off/Proxy/TUN схлопывается в
/// Off/On (см. ROADMAP.md, трек 19, Phase 4): [simplifiedOnOff] прячет
/// сегмент "Proxy" и подписывает TUN-сегмент как "On". `onChanged` тогда
/// вызывается только с [ConnectSelection.off]/[ConnectSelection.tun].
///
/// Содержимое плитки `modeSelector` (`home_tiles/home_tile_content.dart`) —
/// без собственного внешнего фона/скругления, это теперь даёт `HomeTileCard`
/// снаружи с настраиваемым [radiusStyle] вместо жёсткой привязки к
/// `Platform.isAndroid`, как было раньше. Сегменты растягиваются на всю
/// ширину плитки ([Expanded]), а не fit-content.
class OffProxyTunSelector extends StatelessWidget {
  final ConnectSelection value;
  final bool busy;
  final bool simplifiedOnOff;
  final HomeTileRadiusStyle radiusStyle;
  final ValueChanged<ConnectSelection> onChanged;

  const OffProxyTunSelector({
    super.key,
    required this.value,
    required this.busy,
    required this.onChanged,
    required this.radiusStyle,
    this.simplifiedOnOff = false,
  });

  @override
  Widget build(BuildContext context) {
    // Чуть меньше радиуса самой плитки — то же соотношение, что было у
    // "трек 10 / сегмент 8" раньше, pill остаётся pill (клэмпится Flutter'ом
    // в любом случае).
    final tileRadius = radiusForStyle(radiusStyle);
    final segmentRadius = radiusStyle == HomeTileRadiusStyle.pill
        ? tileRadius
        : (tileRadius - 2).clamp(2.0, tileRadius);
    return Row(
      children: [
        Expanded(
          child: _Segment(
            selected: value == ConnectSelection.off,
            enabled: !busy,
            label: 'Off',
            radius: segmentRadius,
            onTap: () => onChanged(ConnectSelection.off),
          ),
        ),
        if (!simplifiedOnOff)
          Expanded(
            child: _Segment(
              selected: value == ConnectSelection.proxy,
              enabled: !busy,
              label: 'Proxy',
              activeColor: const Color(0xFF4ADE80),
              radius: segmentRadius,
              onTap: () => onChanged(ConnectSelection.proxy),
            ),
          ),
        Expanded(
          child: _Segment(
            selected: value == ConnectSelection.tun,
            enabled: !busy,
            label: simplifiedOnOff ? 'On' : 'TUN',
            // "On" (Android) красится в зелёный — тот же акцент, что у
            // Proxy на десктопе, смотрится приятнее синего для простого
            // Off/On. TUN на десктопе остаётся синим, не трогаем.
            activeColor: simplifiedOnOff
                ? const Color(0xFF4ADE80)
                : const Color(0xFF60A5FA),
            radius: segmentRadius,
            onTap: () => onChanged(ConnectSelection.tun),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatefulWidget {
  final bool selected;
  final bool enabled;
  final String label;
  final Color? activeColor;
  final double radius;
  final VoidCallback onTap;

  const _Segment({
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.activeColor,
    this.radius = 8,
  });

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = !widget.enabled
        ? PortColors.mutedForeground.withValues(alpha: 0.4)
        : widget.selected
        ? (widget.activeColor ?? PortColors.foreground)
        : PortColors.mutedForeground;

    // Невыбранный сегмент на ховере чуть подсвечивается (та же формула, что
    // и у выбора в дереве серверов) — иначе непонятно, что по нему вообще
    // можно кликнуть, пока не наведёшь и не увидишь смену курсора.
    final background = widget.selected
        ? PortColors.background
        : (widget.enabled && _hovered ? PortColors.accent.withValues(alpha: 0.5) : null);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.selected
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
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(widget.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
