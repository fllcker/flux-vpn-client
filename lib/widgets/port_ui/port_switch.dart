part of 'port_ui.dart';

/// Switch — switch.tsx. Трек w-8 h-[1.15rem] (32x18.4), thumb size-4 (16),
/// checked: track=primary/thumb=primary-foreground(dark, ИНВЕРСИЯ — легко
/// упустить при порте на глаз), unchecked: track=input(dark)/thumb=foreground.
class PortSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  // Фон, НАД которым лежит трек — нужен для альфа-блендинга unchecked-цвета
  // (dark:bg-input/80 компонует альфу поверх реального фона позади).
  final Color trackBaseColor;

  const PortSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.trackBaseColor = PortColors.background,
  });

  static const _w = 32.0;
  static const _h = 18.4;
  static const _thumb = 16.0;
  static const _pad = 2.0;

  @override
  Widget build(BuildContext context) {
    final track = _Interactive(
      scaleOnPress: false,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      builder: (context, {required hovered, required focused, required pressed}) {
        final trackColor = value
            ? PortColors.primary
            : Color.lerp(trackBaseColor, Colors.white, 0.15 * 0.8)!;
        final thumbColor = value ? PortColors.primaryForeground : PortColors.foreground;
        return AnimatedContainer(
          duration: _kDuration,
          curve: _kEase,
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (focused) BoxShadow(color: PortColors.ring.withValues(alpha: 0.5), spreadRadius: 3),
            ],
          ),
          child: AnimatedAlign(
            duration: _kDuration,
            curve: _kEase,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pad),
              child: Container(
                width: _thumb,
                height: _thumb,
                decoration: BoxDecoration(color: thumbColor, shape: BoxShape.circle),
              ),
            ),
          ),
        );
      },
    );

    if (label == null) return track;

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Expanded(child: DefaultTextStyle.merge(style: PortText.p, child: label!)),
          const SizedBox(width: 12),
          track,
        ],
      ),
    );
  }
}
