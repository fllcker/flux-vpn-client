import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_config.dart';
import 'profile_storage.dart';
import 'proxy_node.dart';
import 'subscription.dart';

/// Профиль приложения — Magic JSON, при старте загружается с диска
/// (`profile_storage.dart`), каждое изменение тут же сохраняется обратно.
final coreConfigProvider = NotifierProvider<CoreConfigController, CoreConfig>(
  CoreConfigController.new,
);

class CoreConfigController extends Notifier<CoreConfig> {
  @override
  CoreConfig build() => profileStorage.load();

  /// Один сервер без подписки — например, из одиночной vless:// ссылки.
  void addServers(List<ServerLeaf> leaves) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions,
        standaloneNodes: [...config.standaloneNodes, ...leaves],
        routingRules: config.routingRules,
      ),
    );
  }

  void addSubscription(Subscription subscription) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: [...config.subscriptions, subscription],
        standaloneNodes: config.standaloneNodes,
        routingRules: config.routingRules,
      ),
    );
  }

  void removeSubscription(String id) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions.where((s) => s.id != id).toList(),
        standaloneNodes: config.standaloneNodes,
        routingRules: config.routingRules,
      ),
    );
  }

  /// Заменяет подписку с тем же [Subscription.id] целиком — используется и
  /// для рефреша (новое дерево серверов/трафик/срок с сервера), и для смены
  /// url/настроек в UI страницы подписки.
  void updateSubscription(Subscription updated) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
        standaloneNodes: config.standaloneNodes,
        routingRules: config.routingRules,
      ),
    );
  }

  /// Выбирает [variantId] как активный вариант подключения для листа
  /// [leafId] — где бы он ни лежал в дереве (standalone или внутри
  /// подписки).
  void selectVariant(String leafId, String variantId) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map(
              (s) => s.copyWith(
                root: replaceLeafSelection(s.root, leafId, variantId),
              ),
            )
            .toList(),
        standaloneNodes: config.standaloneNodes
            .map((n) => replaceLeafSelection(n, leafId, variantId))
            .toList(),
        routingRules: config.routingRules,
      ),
    );
  }

  /// Скрывает/возвращает узел с [nodeId] — только внутри подписок
  /// (`standaloneNodes` не трогаем, они скрытие не поддерживают, см.
  /// ROADMAP.md, трек 2).
  void setHidden(String nodeId, bool hidden) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map((s) => s.copyWith(root: setNodeHidden(s.root, nodeId, hidden)))
            .toList(),
        standaloneNodes: config.standaloneNodes,
        routingRules: config.routingRules,
      ),
    );
  }

  void _update(CoreConfig Function(CoreConfig config) transform) {
    state = transform(state);
    profileStorage.save(state);
  }
}
