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
      // Clip.none по умолчанию — если у глифа эмодзи-шрифта визуальный
      // размер заметно больше номинального fontSize (обычное дело для
      // цветных эмодзи), он раньше просто вылезал за пределы кружка,
      // необрезанным.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PortColors.background,
        border: Border.all(color: PortColors.border),
      ),
      child: _CenteredGlyph(glyph: icon ?? '🌐', fontSize: size * 0.5),
    );
  }
}

/// `Alignment.center`/`textAlign` центрируют БОКС строки (ascent+descent
/// шрифта, обычно заметно выше самого `fontSize` — это "лидинг", воздух
/// сверху/снизу глифа), а не реальные границы глифа — у эмодзи-шрифтов
/// лидинг распределён неравномерно между ascent/descent, из-за чего глиф
/// визуально едет от геометрического центра кружка. Две первые попытки
/// (`StrutStyle(forceStrutHeight: true)`, потом ручной сдвиг по
/// `TextPainter.getBoxesForSelection`) не помогли — `getBoxesForSelection`
/// тоже мерит бокс по метрикам строки, а не по чернильным границам глифа,
/// так что оказывался тем же самым боксом с тем же центром.
/// `TextHeightBehavior(applyHeightToFirstAscent/LastDescent: false)` —
/// официальный API Flutter именно для этого: убирает лидинг совсем, высота
/// строки становится строго `fontSize`, без асимметрии ascent/descent.
class _CenteredGlyph extends StatelessWidget {
  final String glyph;
  final double fontSize;

  const _CenteredGlyph({required this.glyph, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        glyph,
        style: TextStyle(fontSize: fontSize, height: 1),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
  }
}
