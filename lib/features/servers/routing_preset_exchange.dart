import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/routing_preset.dart';

/// Портируемое представление пресета для JSON-обмена (импорт по ссылке /
/// экспорт в буфер обмена) — не [RoutingPreset.toJson] напрямую: тот тащит
/// `id`/`source`/`subscriptionId`/`sourceUrl`, которые при импорте должны
/// быть заменены на локальные значения, а не взяты из файла.
Map<String, dynamic> exportRoutingPresetJson(RoutingPreset preset) => {
  'name': preset.name,
  'rules': preset.rules.map((r) => r.toJson()).toList(),
  'defaultOutboundTag': preset.defaultOutboundTag,
};

/// Пресет, распарсенный из импортированного JSON, ещё без `id`/`source` —
/// их выставляет вызывающая сторона (`settings_page.dart`, тем же
/// `Uuid().v4()`, что и при ручном создании пресета).
class RoutingPresetBlueprint {
  final String name;
  final List<RoutingRule> rules;
  final String defaultOutboundTag;

  const RoutingPresetBlueprint({
    required this.name,
    required this.rules,
    required this.defaultOutboundTag,
  });
}

/// Принимает уже раскодированный JSON в одной из трёх верхнеуровневых форм:
/// голый объект пресета, `{"presets": [...]}`, либо голый массив пресетов —
/// пользователь может публиковать что угодно из этого по прямой ссылке
/// (например, raw GitHub JSON).
List<RoutingPresetBlueprint> parseRoutingPresetBlueprints(dynamic json) {
  final rawList = switch (json) {
    List<dynamic> list => list,
    {'presets': List<dynamic> list} => list,
    Map<String, dynamic> single => [single],
    _ => throw const FormatException('Unrecognized routing preset format'),
  };
  if (rawList.isEmpty) {
    throw const FormatException('No routing presets found');
  }
  return [for (final raw in rawList) _parseOne(raw as Map<String, dynamic>)];
}

RoutingPresetBlueprint _parseOne(Map<String, dynamic> json) {
  final name = (json['name'] as String?)?.trim();
  if (name == null || name.isEmpty) {
    throw const FormatException('Routing preset is missing a name');
  }
  final rules = ((json['rules'] as List?) ?? const [])
      .map((r) => RoutingRule.fromJson(r as Map<String, dynamic>))
      .toList();
  return RoutingPresetBlueprint(
    name: name,
    rules: rules,
    defaultOutboundTag: json['defaultOutboundTag'] as String? ?? 'proxy',
  );
}

/// Скачивает и парсит пресет(ы) роутинга по прямой ссылке — разовое
/// действие, не живая подписка с автообновлением (в отличие от
/// `ServerSubscription`): вызывающая сторона просто добавляет результат в
/// профиль один раз, ссылка после этого нигде не хранится как источник для
/// обновлений (только для показа "импортировано из...", см.
/// `RoutingPreset.sourceUrl`).
Future<List<RoutingPresetBlueprint>> fetchRoutingPresetBlueprints(
  String url,
) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw FormatException('HTTP ${response.statusCode}');
  }
  return parseRoutingPresetBlueprints(jsonDecode(response.body));
}
