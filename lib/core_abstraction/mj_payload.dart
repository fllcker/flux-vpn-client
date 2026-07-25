import 'proxy_node.dart';
import 'subscription.dart';

const _mjPayloadSchemaVersion = 1;

/// Конверт, которым внешний сервис подписки может отдать Magic JSON
/// напрямую по URL подписки — альтернатива xray-json/base64-подписке (см.
/// docs/magic_json.md). В отличие от [CoreConfig] (весь локальный профиль:
/// много подписок + standalone-узлы разом — так его отдавать по одному URL
/// странно), единица передачи тут — то, что реально можно получить одним
/// запросом: либо набор [Subscription] целиком (обычно один элемент, но
/// сервис может прислать сразу несколько), либо плоский набор [ProxyNode]
/// без подписки-обёртки (аналог standalone-серверов).
///
/// ```json
/// { "schemaVersion": 1, "type": "subscriptions", "content": [ {Subscription...} ] }
/// { "schemaVersion": 1, "type": "nodes", "content": [ {ProxyNode...} ] }
/// ```
sealed class MjPayload {
  const MjPayload();

  factory MjPayload.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int?;
    if (schemaVersion != _mjPayloadSchemaVersion) {
      throw FormatException(
        'Unsupported Magic JSON schemaVersion: $schemaVersion '
        '(current is $_mjPayloadSchemaVersion)',
      );
    }
    final content = json['content'];
    if (content is! List) {
      throw const FormatException('Magic JSON: "content" must be an array');
    }
    return switch (json['type']) {
      'subscriptions' => MjSubscriptionsPayload(
          content
              .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
              .toList(),
        ),
      'nodes' => MjNodesPayload(
          content
              .map((n) => ProxyNode.fromJson(n as Map<String, dynamic>))
              .toList(),
        ),
      final type => throw FormatException('Unknown Magic JSON type: $type'),
    };
  }

  /// Отличает MJ-конверт от xray-json подписки при разборе тела ответа —
  /// оба формата — JSON-объект, но у xray-json нет `schemaVersion`/`type` на
  /// верхнем уровне (только `remarks`/`outbounds`), см.
  /// `subscription_import.dart`.
  static bool looksLikePayload(Map<String, dynamic> json) =>
      json['schemaVersion'] != null &&
      (json['type'] == 'subscriptions' || json['type'] == 'nodes') &&
      json['content'] is List;
}

class MjSubscriptionsPayload extends MjPayload {
  final List<Subscription> subscriptions;
  const MjSubscriptionsPayload(this.subscriptions);
}

class MjNodesPayload extends MjPayload {
  final List<ProxyNode> nodes;
  const MjNodesPayload(this.nodes);
}
