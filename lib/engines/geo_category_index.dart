import 'dart:io';
import 'dart:typed_data';

import '../core_abstraction/geo_dat_format.dart';
import 'geo_assets.dart';

/// Список имён всех категорий geosite/geoip — для автокомплита в поле
/// значения правила (`routing_rules_dialog.dart`). Мемоизировано: `.dat`
/// парсится один раз за запуск приложения, а не при каждом открытии
/// диалога — прогревается на старте (`connection_screen.dart`,
/// `_ensureGeoAssets`), не блокируя открытие диалога, если старт ещё не
/// успел его прогреть (первый вызов просто дождётся парсинга сам).
Future<List<String>>? _geositeNames;
Future<List<String>>? _geoipNames;

Future<List<String>> geositeCategoryNames() =>
    _geositeNames ??= _loadNames(geositeFilePath(), parseGeoSiteDat, (e) => e.countryCode);

Future<List<String>> geoipCategoryNames() =>
    _geoipNames ??= _loadNames(geoipFilePath(), parseGeoIpDat, (e) => e.countryCode);

/// Файла нет (ещё не докачан/недоступен на этой платформе) или он битый —
/// это лишь источник подсказок, а не критичный путь, поэтому молча
/// возвращаем пустой список вместо пробрасывания ошибки.
Future<List<String>> _loadNames<T>(
  String path,
  List<T> Function(Uint8List) parse,
  String Function(T) nameOf,
) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return const [];
    final bytes = await file.readAsBytes();
    final names = {for (final entry in parse(bytes)) nameOf(entry).toLowerCase()}.toList()
      ..sort();
    return names;
  } catch (_) {
    return const [];
  }
}
