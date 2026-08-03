import 'proxy_node.dart';

/// `user` — создан вручную в настройках. `subscription` — задел на будущее
/// (ROADMAP): подписка сможет поставлять свои пресеты через Magic JSON,
/// сейчас нигде не создаётся. `importedUrl` — импортирован по прямой ссылке
/// (см. `routing_preset_exchange.dart`), разово, не живая подписка.
enum RoutingPresetSource { user, subscription, importedUrl }

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

  /// Ссылка, с которой импортирован пресет — задана только при
  /// [RoutingPresetSource.importedUrl], для отображения в UI "импортировано
  /// из...". Обновление уже НЕ живёт по этой ссылке — импорт разовый.
  final String? sourceUrl;

  /// Куда уходит трафик, не попавший ни под одно правило — `"proxy"` (дефолт,
  /// прежнее захардкоженное поведение) / `"direct"` / `"block"`.
  final String defaultOutboundTag;

  const RoutingPreset({
    required this.id,
    required this.name,
    required this.rules,
    this.source = RoutingPresetSource.user,
    this.subscriptionId,
    this.sourceUrl,
    this.defaultOutboundTag = 'proxy',
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
    sourceUrl: json['sourceUrl'] as String?,
    defaultOutboundTag: json['defaultOutboundTag'] as String? ?? 'proxy',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rules': rules.map((r) => r.toJson()).toList(),
    'source': source.name,
    if (subscriptionId != null) 'subscriptionId': subscriptionId,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'defaultOutboundTag': defaultOutboundTag,
  };

  RoutingPreset copyWith({
    String? name,
    List<RoutingRule>? rules,
    String? defaultOutboundTag,
  }) => RoutingPreset(
    id: id,
    name: name ?? this.name,
    rules: rules ?? this.rules,
    source: source,
    subscriptionId: subscriptionId,
    sourceUrl: sourceUrl,
    defaultOutboundTag: defaultOutboundTag ?? this.defaultOutboundTag,
  );
}
