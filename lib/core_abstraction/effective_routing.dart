import 'proxy_node.dart';
import 'routing_preset.dart';

/// Разрешает, какие [RoutingRule] реально применять к [leaf] при
/// подключении: `null` [activePresetId] (пресет "Роутинг сервера", дефолт)
/// — правила самого листа, как раньше; иначе — правила пресета с этим id из
/// [presets]. Если пресет успели удалить, а `activeRoutingPresetId` в
/// настройках ещё указывает на него — откатываемся на роутинг сервера, а не
/// падаем/обнуляем правила молча.
List<RoutingRule> effectiveRoutingRules({
  required ServerLeaf leaf,
  required String? activePresetId,
  required List<RoutingPreset> presets,
}) {
  if (activePresetId == null) return leaf.routingRules;
  for (final preset in presets) {
    if (preset.id == activePresetId) return preset.rules;
  }
  return leaf.routingRules;
}

/// Симметричный [effectiveRoutingRules] — куда уходит трафик, не попавший ни
/// под одно правило. Пресет "Роутинг сервера" ([activePresetId] `null`) не
/// имеет собственного поля под это — раньше поведение было жёстко зашито в
/// движках, оставляем как есть: `"proxy"`.
String effectiveDefaultOutboundTag({
  required String? activePresetId,
  required List<RoutingPreset> presets,
}) {
  if (activePresetId == null) return 'proxy';
  for (final preset in presets) {
    if (preset.id == activePresetId) return preset.defaultOutboundTag;
  }
  return 'proxy';
}

/// Человекочитаемое имя действующего пресета — только для диагностики
/// (заголовок в лог-файле движка, см. [CoreEngine.start]), не для UI (там
/// свои локализованные строки, `S.serverRoutingPreset`).
String effectiveRoutingLabel({
  required String? activePresetId,
  required List<RoutingPreset> presets,
}) {
  if (activePresetId == null) return 'server-routing';
  for (final preset in presets) {
    if (preset.id == activePresetId) return preset.name;
  }
  return 'server-routing';
}
