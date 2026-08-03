import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_config.dart';
import 'profile_storage.dart';
import 'proxy_node.dart';
import 'routing_preset.dart';
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
        routingPresets: config.routingPresets,
      ),
    );
  }

  /// Применяет MJ 'nodes' конверт (см. `mj_payload.dart`) — узлы с id,
  /// совпадающим с уже существующим standalone-узлом, заменяются им целиком
  /// на месте, новые id дописываются в конец. Не трогает узлы внутри
  /// подписок — 'nodes' по определению плоский набор без подписки-обёртки.
  void applyMjNodes(List<ProxyNode> nodes) {
    _update((config) {
      final incomingIds = nodes.map((n) => n.id).toSet();
      final kept = config.standaloneNodes.where(
        (n) => !incomingIds.contains(n.id),
      );
      return CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions,
        standaloneNodes: [...kept, ...nodes],
        routingPresets: config.routingPresets,
      );
    });
  }

  void addSubscription(Subscription subscription) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: [...config.subscriptions, subscription],
        standaloneNodes: config.standaloneNodes,
        routingPresets: config.routingPresets,
      ),
    );
  }

  void removeSubscription(String id) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions.where((s) => s.id != id).toList(),
        standaloneNodes: config.standaloneNodes,
        routingPresets: config.routingPresets,
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
        routingPresets: config.routingPresets,
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
        routingPresets: config.routingPresets,
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
        routingPresets: config.routingPresets,
      ),
    );
  }

  /// Добавляет новый пользовательский пресет роутинга — см.
  /// `routing_preset.dart`, `settings_page.dart`.
  void addRoutingPreset(RoutingPreset preset) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions,
        standaloneNodes: config.standaloneNodes,
        routingPresets: [...config.routingPresets, preset],
      ),
    );
  }

  /// Заменяет пресет с тем же [RoutingPreset.id] целиком (переименование
  /// и/или правки правил).
  void updateRoutingPreset(RoutingPreset updated) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions,
        standaloneNodes: config.standaloneNodes,
        routingPresets: config.routingPresets
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      ),
    );
  }

  /// Удаляет пресет [presetId]. Если он был активным
  /// (`AppSettings.activeRoutingPresetId`), настройки нужно откатить на
  /// "Роутинг сервера" отдельно — контроллер этого не знает, см.
  /// `settings_page.dart`.
  void deleteRoutingPreset(String presetId) {
    _update(
      (config) => CoreConfig(
        schemaVersion: config.schemaVersion,
        subscriptions: config.subscriptions,
        standaloneNodes: config.standaloneNodes,
        routingPresets:
            config.routingPresets.where((p) => p.id != presetId).toList(),
      ),
    );
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
        routingPresets: config.routingPresets,
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
          routingPresets: config.routingPresets,
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
        routingPresets: config.routingPresets,
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
