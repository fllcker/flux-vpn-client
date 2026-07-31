import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../app/app_paths.dart';
import '../../core_abstraction/geo_dat_format.dart';
import '../../core_abstraction/proxy_node.dart';
import '../geo_assets.dart';
import 'singbox_config_mapper.dart' show geoRuleSetReferences;

/// Конвертирует запрошенную geosite/geoip-категорию из уже скачанных
/// `geoip.dat`/`geosite.dat` (см. `geo_assets.dart`, ROADMAP.md трек 20) в
/// JSON rule-set, который sing-box понимает нативно в рантайме
/// (`format: "source"` — компиляция в `.srs` не обязательна) — см.
/// ROADMAP.md, трек 21. sing-box сам не умеет читать xray-протобаф-формат
/// (проверено на бинарнике 1.13.14 — `rule-set convert`/`geoip`/`geosite`
/// subcommands рассчитаны только на собственный SagerNet-`.db`), поэтому
/// разбор `.dat` сделан своим парсером (`geo_dat_format.dart`), а не через
/// сам sing-box.
///
/// Результат кэшируется на диске по (категория, mtime исходного `.dat`) —
/// повторный вызов с тем же исходником не перепарсивает файл заново.
/// Обновление `.dat` (кнопка в настройках/новая закачка при старте) меняет
/// mtime, так что старые файлы кэша просто перестают совпадать по имени —
/// они не удаляются активно (не то место, где имеет смысл ещё и чистить,
/// это дёшево оставить копиться, каталог мелкий).
Future<String> geositeRuleSetPath(String category) => _ruleSetPath(
  prefix: 'geosite',
  category: category,
  sourcePath: geositeFilePath(),
  build: (Uint8List bytes) {
    final entry = findGeoSiteCategory(parseGeoSiteDat(bytes), category);
    return _geositeRuleSetJson(entry);
  },
);

Future<String> geoipRuleSetPath(String category) => _ruleSetPath(
  prefix: 'geoip',
  category: category,
  sourcePath: geoipFilePath(),
  build: (Uint8List bytes) {
    final entry = findGeoIpCategory(parseGeoIpDat(bytes), category);
    return _geoipRuleSetJson(entry);
  },
);

/// Прогревает кэш rule-set'ов для всех geosite/geoip-категорий, на которые
/// ссылаются переданные правила — вызывается сразу после обновления
/// `geoip.dat`/`geosite.dat` (при старте приложения и по кнопке "Обновить
/// базы роутинга" в настройках), а не только лениво в момент подключения к
/// TUN. Без прогрева первое подключение после (пере)установки/обновления баз
/// само делает эту конвертацию — на реальных файлах (десятки мегабайт)
/// заметная пауза перед подъёмом TUN (проверено пользователем — порядка 5
/// секунд), которую лучше вынести в фон заранее, а не в момент, когда
/// пользователь ждёт подключения.
///
/// Best-effort: категория, которой почему-то нет в текущем `.dat` (сервис
/// прописал в `routingRules` `geosite:xxx`, а базы ещё не успели его
/// подхватить), тихо пропускается здесь — ошибка всё равно всплывёт при
/// реальном подключении, где она уже видна в логе, не молча теряется.
Future<void> pregenerateGeoRuleSets(List<RoutingRule> allRoutingRules) async {
  for (final tag in geoRuleSetReferences(allRoutingRules)) {
    final category = tag.substring(tag.indexOf('-') + 1);
    try {
      if (tag.startsWith('geosite-')) {
        await geositeRuleSetPath(category);
      } else {
        await geoipRuleSetPath(category);
      }
    } catch (_) {
      // best-effort — см. doc-комментарий выше
    }
  }
}

Future<String> _ruleSetPath({
  required String prefix,
  required String category,
  required String sourcePath,
  required Map<String, dynamic> Function(Uint8List bytes) build,
}) async {
  final sourceFile = File(sourcePath);
  final mtime = sourceFile.statSync().modified.millisecondsSinceEpoch;
  final cachePath =
      '${ensureFluxGeoRuleSetDirectory()}${Platform.pathSeparator}'
      '$prefix-${_sanitize(category)}-$mtime.json';

  final cacheFile = File(cachePath);
  if (cacheFile.existsSync()) return cachePath;

  final bytes = await sourceFile.readAsBytes();
  final ruleSet = build(bytes);
  await cacheFile.writeAsString(jsonEncode(ruleSet));
  return cachePath;
}

/// Имя категории идёт в имя файла как есть в `RoutingRule` (например
/// `category-ads`, `cn`) — только страховка от случайных `/`/`\` в значении
/// (сервис прислал что-то странное в `geosite:...` — не даём этому вырваться
/// за пределы каталога rule-set'ов).
String _sanitize(String category) =>
    category.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

Map<String, dynamic> _geositeRuleSetJson(GeoSiteEntry entry) {
  final domain = <String>[];
  final domainSuffix = <String>[];
  final domainKeyword = <String>[];
  final domainRegex = <String>[];
  for (final d in entry.domains) {
    switch (d.type) {
      case GeoDomainType.full:
        domain.add(d.value);
      case GeoDomainType.domain:
        domainSuffix.add(d.value);
      case GeoDomainType.plain:
        domainKeyword.add(d.value);
      case GeoDomainType.regex:
        domainRegex.add(d.value);
    }
  }
  return {
    'version': 1,
    'rules': [
      {
        if (domain.isNotEmpty) 'domain': domain,
        if (domainSuffix.isNotEmpty) 'domain_suffix': domainSuffix,
        if (domainKeyword.isNotEmpty) 'domain_keyword': domainKeyword,
        if (domainRegex.isNotEmpty) 'domain_regex': domainRegex,
      },
    ],
  };
}

Map<String, dynamic> _geoipRuleSetJson(GeoIpEntry entry) => {
  'version': 1,
  'rules': [
    {
      'ip_cidr': [for (final c in entry.cidrs) c.cidr],
    },
  ],
};
