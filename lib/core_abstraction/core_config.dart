import 'proxy_node.dart';
import 'routing_preset.dart';
import 'subscription.dart';

const _currentSchemaVersion = 1;

/// Magic JSON (MJ) — канонический, независимый от конкретного ядра формат
/// профиля. Каждый [CoreEngine] экспортирует из него свой нативный конфиг
/// (для xray — xray JSON). См. PLAN.md, "Единый формат конфига".
///
/// [schemaVersion] обязателен для обратной совместимости — при добавлении
/// полей см. правило "обратная совместимость Magic JSON" в PLAN.md. Пока
/// существует только версия 1, миграций ещё нет.
///
/// Правила роутинга по умолчанию всё ещё берутся с [ServerLeaf]
/// (`ServerLeaf.routingRules`) — но теперь это лишь фоллбек для пресета
/// "Роутинг сервера" (`AppSettings.activeRoutingPresetId == null`). Если
/// выбран другой пресет из [routingPresets], он применяется вместо этого ко
/// всем серверам сразу — см. `effective_routing.dart`.
class CoreConfig {
  final int schemaVersion;
  final List<Subscription> subscriptions;
  final List<ProxyNode> standaloneNodes; // серверы/группы вне подписок
  final List<RoutingPreset> routingPresets;

  const CoreConfig({
    this.schemaVersion = _currentSchemaVersion,
    this.subscriptions = const [],
    this.standaloneNodes = const [],
    this.routingPresets = const [],
  });

  factory CoreConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != _currentSchemaVersion) {
      throw FormatException(
        'Unsupported Magic JSON schemaVersion: $schemaVersion '
        '(no migrations defined yet, current is $_currentSchemaVersion)',
      );
    }

    return CoreConfig(
      schemaVersion: schemaVersion,
      subscriptions: ((json['subscriptions'] as List?) ?? const [])
          .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
          .toList(),
      standaloneNodes: ((json['standaloneNodes'] as List?) ?? const [])
          .map((n) => ProxyNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      routingPresets: ((json['routingPresets'] as List?) ?? const [])
          .map((p) => RoutingPreset.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'standaloneNodes': standaloneNodes.map((n) => n.toJson()).toList(),
    if (routingPresets.isNotEmpty)
      'routingPresets': routingPresets.map((p) => p.toJson()).toList(),
  };
}
