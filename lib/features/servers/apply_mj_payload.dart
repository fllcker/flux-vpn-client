import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/mj_payload.dart';
import '../../l10n/strings.dart';
import 'merge_subscription_tree.dart';

/// Применяет распарсенный MJ-конверт (см. `mj_payload.dart`) к профилю —
/// общая логика для диалога добавления сервера и глобальной вставки по
/// Ctrl+V, оба разбирают `LinkImportResult` и на `MjImportResultOk` зовут
/// это. Возвращает короткое описание того, что произошло — для тоста/
/// сообщения в UI.
String applyMjPayload(WidgetRef ref, MjPayload payload) {
  final notifier = ref.read(coreConfigProvider.notifier);

  switch (payload) {
    case MjSubscriptionsPayload(:final subscriptions):
      final existing = ref.read(coreConfigProvider).subscriptions;
      var added = 0;
      var updated = 0;
      for (final incoming in subscriptions) {
        final match = existing.where((s) => s.id == incoming.id).firstOrNull;
        if (match != null) {
          notifier.updateSubscription(
            incoming.copyWith(
              root: mergeSubscriptionTree(match.root, incoming.root),
            ),
          );
          updated++;
        } else {
          notifier.addSubscription(incoming);
          added++;
        }
      }
      return switch ((added, updated)) {
        (final a, 0) => S.subscriptionsAdded(a),
        (0, final u) => S.subscriptionsUpdated(u),
        (final a, final u) => S.subscriptionsAddedAndUpdated(a, u),
      };
    case MjNodesPayload(:final nodes):
      notifier.applyMjNodes(nodes);
      return S.serversFromMagicJson(nodes.length);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
