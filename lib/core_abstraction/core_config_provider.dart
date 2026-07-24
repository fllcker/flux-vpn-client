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
      ),
    );
  }

  void addSubscription(Subscription subscription) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: [...config.subscriptions, subscription],
        standaloneNodes: config.standaloneNodes,
      ),
    );
  }

  void removeSubscription(String id) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions.where((s) => s.id != id).toList(),
        standaloneNodes: config.standaloneNodes,
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
      ),
    );
  }

  /// Заменяет [ServerLeaf.routingRules] одного сервера [leafId] — где бы он
  /// ни лежал в дереве (standalone или внутри подписки), см. ROADMAP.md,
  /// трек 3.
  void setRoutingRules(String leafId, List<RoutingRule> rules) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map(
              (s) => s.copyWith(
                root: setLeafRoutingRules(s.root, leafId, rules),
              ),
            )
            .toList(),
        standaloneNodes: config.standaloneNodes
            .map((n) => setLeafRoutingRules(n, leafId, rules))
            .toList(),
      ),
    );
  }

  /// Bulk-применение: перезаписывает [rules] у каждого [ServerLeaf] подписки
  /// [subscriptionId] одним и тем же списком — см. ROADMAP.md, трек 3, "На
  /// странице подписки".
  void setRoutingRulesForSubscription(
    String subscriptionId,
    List<RoutingRule> rules,
  ) {
    _update((config) {
      final subscription = config.subscriptions
          .where((s) => s.id == subscriptionId)
          .firstOrNull;
      if (subscription == null) return config;

      var root = subscription.root;
      for (final leaf in _flattenLeaves(root)) {
        root = setLeafRoutingRules(root, leaf.id, rules);
      }

      return CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map((s) => s.id == subscriptionId ? s.copyWith(root: root) : s)
            .toList(),
        standaloneNodes: config.standaloneNodes,
      );
    });
  }

  /// Запоминает, что для группы [groupId] последний раз использовался
  /// авто-выбор по задержке — см. ROADMAP.md, трек 5. Само подключение уже
  /// выполнено к моменту вызова (см. `pick_best_by_latency.dart`), это
  /// только фиксация факта на модели.
  void markGroupAutoSelected(String groupId) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map(
              (s) => s.copyWith(
                root: setGroupStrategy(s.root, groupId, GroupStrategy.urlTest),
              ),
            )
            .toList(),
        standaloneNodes: config.standaloneNodes
            .map((n) => setGroupStrategy(n, groupId, GroupStrategy.urlTest))
            .toList(),
      ),
    );
  }

  /// Перемещает узел [nodeId] так, чтобы он стал элементом [newIndex] в
  /// `children` группы [newParentGroupId] — либо, если [newParentGroupId] ==
  /// [standaloneParentId], элементом [newIndex] плоского списка
  /// standalone-серверов. Перетаскивание работает только внутри одного
  /// дерева (одной подписки) или внутри standalone-списка — источник и цель
  /// в разных деревьях друг для друга просто не существуют, поэтому
  /// операция no-op'ится сама (см. `moveNodeInTree`), см. ROADMAP.md, трек 6.
  void moveNode(String nodeId, String newParentGroupId, int newIndex) {
    if (newParentGroupId == standaloneParentId) {
      _update(
        (config) => CoreConfig(
          schemaVersion: config.schemaVersion,
          subscriptions: config.subscriptions,
          standaloneNodes: _reorderStandalone(
            config.standaloneNodes,
            nodeId,
            newIndex,
          ),
        ),
      );
      return;
    }

    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions
            .map(
              (s) => s.copyWith(
                root: moveNodeInTree(s.root, nodeId, newParentGroupId, newIndex),
              ),
            )
            .toList(),
        standaloneNodes: config.standaloneNodes,
      ),
    );
  }

  void _update(CoreConfig Function(CoreConfig config) transform) {
    state = transform(state);
    profileStorage.save(state);
  }
}

/// Значение [newParentGroupId] для `CoreConfigController.moveNode`, когда
/// цель перетаскивания — плоский список standalone-серверов, а не группа
/// внутри подписки (у standalone-списка нет обёртки-`ServerGroup`, значит и
/// нет собственного id).
const standaloneParentId = '__standalone__';

List<ProxyNode> _reorderStandalone(
  List<ProxyNode> nodes,
  String nodeId,
  int newIndex,
) {
  final index = nodes.indexWhere((n) => n.id == nodeId);
  if (index == -1) return nodes;
  final updated = List<ProxyNode>.of(nodes)..removeAt(index);
  updated.insert(newIndex.clamp(0, updated.length), nodes[index]);
  return updated;
}

List<ServerLeaf> _flattenLeaves(ProxyNode node) {
  return switch (node) {
    ServerLeaf leaf => [leaf],
    AutoSelectMarker() => const [],
    ServerGroup group => [
      for (final child in group.children) ..._flattenLeaves(child),
    ],
  };
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
