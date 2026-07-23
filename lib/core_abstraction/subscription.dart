import 'proxy_node.dart';

class TrafficInfo {
  final int usedBytes;
  final int totalBytes;

  const TrafficInfo({required this.usedBytes, required this.totalBytes});

  factory TrafficInfo.fromJson(Map<String, dynamic> json) => TrafficInfo(
    usedBytes: json['usedBytes'] as int,
    totalBytes: json['totalBytes'] as int,
  );

  Map<String, dynamic> toJson() => {
    'usedBytes': usedBytes,
    'totalBytes': totalBytes,
  };
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

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      pictureUrl: json['pictureUrl'] as String?,
      annotation: json['annotation'] as String?,
      traffic: json['traffic'] == null
          ? null
          : TrafficInfo.fromJson(json['traffic'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      lastRefreshedAt: json['lastRefreshedAt'] == null
          ? null
          : DateTime.parse(json['lastRefreshedAt'] as String),
      root: ProxyNode.fromJson(json['root'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (pictureUrl != null) 'pictureUrl': pictureUrl,
    if (annotation != null) 'annotation': annotation,
    if (traffic != null) 'traffic': traffic!.toJson(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (lastRefreshedAt != null)
      'lastRefreshedAt': lastRefreshedAt!.toIso8601String(),
    'root': root.toJson(),
  };
}
