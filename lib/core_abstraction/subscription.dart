import 'proxy_node.dart';

class TrafficInfo {
  final int usedBytes;
  final int totalBytes;

  const TrafficInfo({required this.usedBytes, required this.totalBytes});
}

/// Родитель дерева групп/серверов, полученных из одной подписки — см.
/// PLAN.md, "Метаданные подписки".
class Subscription {
  final String id;
  final String name;
  final String url;
  final String? pictureUrl;
  final String? annotation;
  final TrafficInfo? traffic;
  final DateTime? expiresAt;
  final DateTime? lastRefreshedAt;
  final ProxyNode root;

  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.pictureUrl,
    this.annotation,
    this.traffic,
    this.expiresAt,
    this.lastRefreshedAt,
    required this.root,
  });
}
