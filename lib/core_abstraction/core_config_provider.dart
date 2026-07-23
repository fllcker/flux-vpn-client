import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_config.dart';
import 'proxy_node.dart';
import 'subscription.dart';

/// Профиль приложения в памяти — Magic JSON без персистентности на диск
/// (сохранение/загрузка файла профиля — отдельная задача).
final coreConfigProvider = NotifierProvider<CoreConfigController, CoreConfig>(
  CoreConfigController.new,
);

class CoreConfigController extends Notifier<CoreConfig> {
  @override
  CoreConfig build() => const CoreConfig();

  /// Один сервер без подписки — например, из одиночной vless:// ссылки.
  void addServers(List<ServerLeaf> leaves) {
    state = CoreConfig(
      schemaVersion: state.schemaVersion,
      subscriptions: state.subscriptions,
      standaloneNodes: [...state.standaloneNodes, ...leaves],
      routingRules: state.routingRules,
    );
  }

  void addSubscription(Subscription subscription) {
    state = CoreConfig(
      schemaVersion: state.schemaVersion,
      subscriptions: [...state.subscriptions, subscription],
      standaloneNodes: state.standaloneNodes,
      routingRules: state.routingRules,
    );
  }
}
