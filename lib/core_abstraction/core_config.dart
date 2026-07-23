import 'proxy_node.dart';
import 'subscription.dart';

/// Правило роутинга — структура не зафиксирована (см. "Открытые вопросы" в
/// PLAN.md), пока пустой маркер для будущего расширения. Без конкретных
/// подтипов сериализовать/десериализовать нечего — [CoreConfig] требует
/// пустой список.
sealed class RoutingRule {
  const RoutingRule();

  Map<String, dynamic> toJson();
}

const _currentSchemaVersion = 1;

/// Magic JSON (MJ) — канонический, независимый от конкретного ядра формат
/// профиля. Каждый [CoreEngine] экспортирует из него свой нативный конфиг
/// (для xray — xray JSON). См. PLAN.md, "Единый формат конфига".
///
/// [schemaVersion] обязателен для обратной совместимости — при добавлении
/// полей см. правило "обратная совместимость Magic JSON" в PLAN.md. Пока
/// существует только версия 1, миграций ещё нет.
class CoreConfig {
  final int schemaVersion;
  final List<Subscription> subscriptions;
  final List<ProxyNode> standaloneNodes; // серверы/группы вне подписок
  final List<RoutingRule> routingRules;

  const CoreConfig({
    this.schemaVersion = _currentSchemaVersion,
    this.subscriptions = const [],
    this.standaloneNodes = const [],
    this.routingRules = const [],
  });

  factory CoreConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != _currentSchemaVersion) {
      throw FormatException(
        'Unsupported Magic JSON schemaVersion: $schemaVersion '
        '(no migrations defined yet, current is $_currentSchemaVersion)',
      );
    }

    final routingRulesJson = json['routingRules'] as List? ?? const [];
    if (routingRulesJson.isNotEmpty) {
      throw const FormatException(
        'routingRules deserialization is not implemented yet',
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
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'standaloneNodes': standaloneNodes.map((n) => n.toJson()).toList(),
    'routingRules': routingRules.map((r) => r.toJson()).toList(),
  };
}
