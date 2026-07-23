import 'proxy_node.dart';
import 'subscription.dart';

/// Правило роутинга — структура не зафиксирована (см. "Открытые вопросы" в
/// PLAN.md), пока пустой маркер для будущего расширения.
sealed class RoutingRule {
  const RoutingRule();
}

/// Magic JSON (MJ) — канонический, независимый от конкретного ядра формат
/// профиля. Каждый [CoreEngine] экспортирует из него свой нативный конфиг
/// (для xray — xray JSON). См. PLAN.md, "Единый формат конфига".
///
/// [schemaVersion] обязателен для обратной совместимости — при добавлении
/// полей см. правило "обратная совместимость Magic JSON" в PLAN.md.
class CoreConfig {
  final int schemaVersion;
  final List<Subscription> subscriptions;
  final List<ProxyNode> standaloneNodes; // серверы/группы вне подписок
  final List<RoutingRule> routingRules;

  const CoreConfig({
    required this.schemaVersion,
    this.subscriptions = const [],
    this.standaloneNodes = const [],
    this.routingRules = const [],
  });
}
