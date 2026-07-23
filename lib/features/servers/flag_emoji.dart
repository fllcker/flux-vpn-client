/// Регион-индикаторные символы (U+1F1E6..U+1F1FF) кодируют флаг-эмодзи как
/// пару латинских букв A-Z. Нужно уметь доставать ISO-код обратно из
/// эмодзи, чтобы рендерить флаг картинкой через `country_flags` — Windows
/// не рисует flag-эмодзи как картинку (см. PLAN.md, "Иконки серверов").
const _regionalIndicatorBase = 0x1F1E6;
const _upperCaseABase = 0x41; // 'A'

/// `null`, если строка — не ровно два regional indicator символа.
String? isoCodeFromFlagEmoji(String? emoji) {
  if (emoji == null) return null;
  final runes = emoji.runes.toList();
  if (runes.length != 2) return null;

  final letters = StringBuffer();
  for (final rune in runes) {
    final offset = rune - _regionalIndicatorBase;
    if (offset < 0 || offset > 25) return null;
    letters.writeCharCode(_upperCaseABase + offset);
  }
  return letters.toString();
}

String flagEmojiFromIsoCode(String code) {
  final codeUnits = code.toUpperCase().codeUnits.map(
    (c) => _regionalIndicatorBase + (c - _upperCaseABase),
  );
  return String.fromCharCodes(codeUnits);
}
