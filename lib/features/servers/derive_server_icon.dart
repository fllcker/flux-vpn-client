import 'flag_emoji.dart';

/// Автоопределение иконки сервера по названию — см. PLAN.md, "Иконки
/// серверов": удобная подсказка по умолчанию, пользователь сможет заменить
/// иконку вручную на любой эмодзи. Панели отдают remarks в одном из двух
/// видов:
/// - уже с флаг-эмодзи в начале ("🇩🇪 Basic - Germany 1", как у Happ);
/// - с двухбуквенным ISO-кодом строкой ("DE Basic - Germany 1").
/// Оба случая переносим в поле icon и убираем из отображаемого имени, чтобы
/// не дублировать.
final _flagEmojiPrefix = RegExp(
  r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*(.+)$',
  unicode: true,
);
final _countryCodePrefix = RegExp(r'^([A-Za-z]{2})[\s\-_]+(.+)$');

({String? icon, String name}) deriveServerIcon(String rawName) {
  final trimmed = rawName.trim();

  final flagMatch = _flagEmojiPrefix.firstMatch(trimmed);
  if (flagMatch != null) {
    return (icon: flagMatch.group(1)!, name: flagMatch.group(2)!);
  }

  final codeMatch = _countryCodePrefix.firstMatch(trimmed);
  if (codeMatch != null) {
    final code = codeMatch.group(1)!.toUpperCase();
    if (_iso3166Alpha2.contains(code)) {
      return (icon: flagEmojiFromIsoCode(code), name: codeMatch.group(2)!);
    }
  }

  return (icon: null, name: rawName);
}

const _iso3166Alpha2 = {
  'AD', 'AE', 'AF', 'AG', 'AI', 'AL', 'AM', 'AO', 'AQ', 'AR', 'AS', 'AT',
  'AU', 'AW', 'AX', 'AZ', 'BA', 'BB', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI',
  'BJ', 'BL', 'BM', 'BN', 'BO', 'BQ', 'BR', 'BS', 'BT', 'BV', 'BW', 'BY',
  'BZ', 'CA', 'CC', 'CD', 'CF', 'CG', 'CH', 'CI', 'CK', 'CL', 'CM', 'CN',
  'CO', 'CR', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ', 'DE', 'DJ', 'DK', 'DM',
  'DO', 'DZ', 'EC', 'EE', 'EG', 'EH', 'ER', 'ES', 'ET', 'FI', 'FJ', 'FK',
  'FM', 'FO', 'FR', 'GA', 'GB', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GL',
  'GM', 'GN', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GU', 'GW', 'GY', 'HK', 'HM',
  'HN', 'HR', 'HT', 'HU', 'ID', 'IE', 'IL', 'IM', 'IN', 'IO', 'IQ', 'IR',
  'IS', 'IT', 'JE', 'JM', 'JO', 'JP', 'KE', 'KG', 'KH', 'KI', 'KM', 'KN',
  'KP', 'KR', 'KW', 'KY', 'KZ', 'LA', 'LB', 'LC', 'LI', 'LK', 'LR', 'LS',
  'LT', 'LU', 'LV', 'LY', 'MA', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MK',
  'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MU', 'MV', 'MW',
  'MX', 'MY', 'MZ', 'NA', 'NC', 'NE', 'NF', 'NG', 'NI', 'NL', 'NO', 'NP',
  'NR', 'NU', 'NZ', 'OM', 'PA', 'PE', 'PF', 'PG', 'PH', 'PK', 'PL', 'PM',
  'PN', 'PR', 'PS', 'PT', 'PW', 'PY', 'QA', 'RE', 'RO', 'RS', 'RU', 'RW',
  'SA', 'SB', 'SC', 'SD', 'SE', 'SG', 'SH', 'SI', 'SJ', 'SK', 'SL', 'SM',
  'SN', 'SO', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ', 'TC', 'TD', 'TF',
  'TG', 'TH', 'TJ', 'TK', 'TL', 'TM', 'TN', 'TO', 'TR', 'TT', 'TV', 'TW',
  'TZ', 'UA', 'UG', 'UM', 'US', 'UY', 'UZ', 'VA', 'VC', 'VE', 'VG', 'VI',
  'VN', 'VU', 'WF', 'WS', 'YE', 'YT', 'ZA', 'ZM', 'ZW',
};
