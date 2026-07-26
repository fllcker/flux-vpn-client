import 'dart:io';

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
    // Android (тест, см. connect_panel.dart) — трек и активный сегмент
    // почти овалы, тот же приём (999 клэмпится Flutter'ом до половины
    // высоты). Десктоп не трогаем.
    final pillRadius = Platform.isAndroid ? 999.0 : 10.0;
    // Сегменты внутри трека раньше были 8 (чуть меньше трека в 10) —
    // сохраняем то же соотношение "чуть меньше" на десктопе, на Android оба
    // 999 всё равно клэмпятся до формы.
    final segmentRadius = Platform.isAndroid ? 999.0 : 8.0;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PortColors.muted.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            selected: value == ConnectSelection.off,
            enabled: !busy,
            label: 'Off',
            // Раньше здесь был увеличенный паддинг (40) — компенсировал то,
            // что 2-сегментный вид растягивался под измеренную ширину
            // карточки сервера сверху (см. _selectorWidth в
            // connect_panel.dart). Теперь на Android оба блока fit-content
            // независимо друг от друга (см. тот же файл), компенсация не
            // нужна — сегмент снова просто в размер своего текста.
            radius: segmentRadius,
            onTap: () => onChanged(ConnectSelection.off),
          ),
          if (!simplifiedOnOff)
            _Segment(
              selected: value == ConnectSelection.proxy,
              enabled: !busy,
              label: 'Proxy',
              activeColor: const Color(0xFF4ADE80),
              radius: segmentRadius,
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
            radius: segmentRadius,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? PortColors.background : null,
            borderRadius: BorderRadius.circular(radius),
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
