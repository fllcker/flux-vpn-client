import 'package:country_flags/country_flags.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/port_ui/port_ui.dart';
import 'flag_emoji.dart';

/// Круглая иконка сервера: если [icon] — эмодзи-флаг, рисуем его картинкой
/// через `country_flags` (см. flag_emoji.dart, почему не просто Text);
/// иначе показываем эмодзи как есть (обычные эмодзи Windows рисует
/// нормально) в кружке того же размера.
class ServerIcon extends StatelessWidget {
  final String? icon;
  final double size;

  const ServerIcon({super.key, required this.icon, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final isoCode = isoCodeFromFlagEmoji(icon);
    if (isoCode != null) {
      return CountryFlag.fromCountryCode(
        isoCode,
        theme: ImageTheme(shape: const Circle(), width: size, height: size),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PortColors.background,
        border: Border.all(color: PortColors.border),
      ),
      child: Text(icon ?? '🌐', style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
