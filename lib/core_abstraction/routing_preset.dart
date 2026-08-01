import 'proxy_node.dart';

/// `user` — создан вручную в настройках. `subscription` — задел на будущее
/// (ROADMAP): подписка сможет поставлять свои пресеты через Magic JSON,
/// сейчас нигде не создаётся.
enum RoutingPresetSource { user, subscription }

/// Именованный набор [RoutingRule] — переключается целиком на уровне
/// приложения (`AppSettings.activeRoutingPresetId`), в отличие от
/// [ServerLeaf.routingRules], который принадлежит одному серверу.
class RoutingPreset {
  final String id;
  final String name;
  final List<RoutingRule> rules;
  final RoutingPresetSource source;

  /// Id подписки-источника — задан только при [RoutingPresetSource.subscription].
  final String? subscriptionId;

  const RoutingPreset({
    required this.id,
    required this.name,
    required this.rules,
    this.source = RoutingPresetSource.user,
    this.subscriptionId,
  });

  factory RoutingPreset.fromJson(Map<String, dynamic> json) => RoutingPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    rules: (json['rules'] as List)
        .map((r) => RoutingRule.fromJson(r as Map<String, dynamic>))
        .toList(),
    source: RoutingPresetSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => RoutingPresetSource.user,
    ),
    subscriptionId: json['subscriptionId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rules': rules.map((r) => r.toJson()).toList(),
    'source': source.name,
    if (subscriptionId != null) 'subscriptionId': subscriptionId,
  };

  RoutingPreset copyWith({String? name, List<RoutingRule>? rules}) =>
      RoutingPreset(
        id: id,
        name: name ?? this.name,
        rules: rules ?? this.rules,
        source: source,
        subscriptionId: subscriptionId,
      );
}
