import 'proxy_node.dart';

const _defaultDomainTimeoutMs = 2500;

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
  final bool autoRefreshOnStartup;
  final ProxyNode root;

  /// Произвольные пары ключ-значение от сервиса подписки (например
  /// `{"Тариф": "Premium"}`), не описанные заранее в модели — см.
  /// ROADMAP.md, трек 14. Часть Magic JSON (в отличие от кэша пинга),
  /// полностью заменяется свежими данными при каждом рефреше, как
  /// [traffic]/[expiresAt].
  final Map<String, String> customFields;

  /// Фоллбек-домены на случай, если основной [url] стал недоступен (DNS,
  /// блокировка, домен сгорел) — см. ROADMAP.md, трек 23. Работает только
  /// на повторных `refreshSubscription`, не на первичном импорте: секция
  /// приходит внутри самой подписки, значит на самый первый фетч, если он
  /// падает, взять её ещё неоткуда.
  ///
  /// [fallbackDomains] — статический список альтернативных доменов,
  /// перебирается по порядку. [fallbackDomainsUrl] — опциональная ссылка на
  /// JSON вида `{"domains": [...]}`, фетчится, когда статический список
  /// исчерпан; результат **заменяет** [fallbackDomains] целиком при
  /// следующем сохранении (отдельного кэша для этого не заводили — сама
  /// подписка и есть постоянное хранилище). [domainTimeoutMs] — таймаут
  /// одной попытки достучаться до конкретного домена (текущего или
  /// очередного фоллбека); лимита количества попыток сверху нет — перебор
  /// естественно ограничен длиной списка.
  final List<String> fallbackDomains;
  final String? fallbackDomainsUrl;
  final int domainTimeoutMs;

  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.pictureUrl,
    this.annotation,
    this.traffic,
    this.expiresAt,
    this.lastRefreshedAt,
    this.autoRefreshOnStartup = false,
    this.customFields = const {},
    this.fallbackDomains = const [],
    this.fallbackDomainsUrl,
    this.domainTimeoutMs = _defaultDomainTimeoutMs,
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
      autoRefreshOnStartup: json['autoRefreshOnStartup'] as bool? ?? false,
      customFields: (json['customFields'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
      fallbackDomains: (json['fallbackDomains'] as List<dynamic>?)
              ?.map((v) => v as String)
              .toList() ??
          const [],
      fallbackDomainsUrl: json['fallbackDomainsUrl'] as String?,
      domainTimeoutMs: json['domainTimeoutMs'] as int? ?? _defaultDomainTimeoutMs,
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
    if (autoRefreshOnStartup) 'autoRefreshOnStartup': autoRefreshOnStartup,
    if (customFields.isNotEmpty) 'customFields': customFields,
    if (fallbackDomains.isNotEmpty) 'fallbackDomains': fallbackDomains,
    if (fallbackDomainsUrl != null) 'fallbackDomainsUrl': fallbackDomainsUrl,
    if (domainTimeoutMs != _defaultDomainTimeoutMs) 'domainTimeoutMs': domainTimeoutMs,
    'root': root.toJson(),
  };

  Subscription copyWith({
    String? name,
    String? url,
    String? pictureUrl,
    String? annotation,
    TrafficInfo? traffic,
    DateTime? expiresAt,
    DateTime? lastRefreshedAt,
    bool? autoRefreshOnStartup,
    Map<String, String>? customFields,
    List<String>? fallbackDomains,
    String? fallbackDomainsUrl,
    int? domainTimeoutMs,
    ProxyNode? root,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      annotation: annotation ?? this.annotation,
      traffic: traffic ?? this.traffic,
      expiresAt: expiresAt ?? this.expiresAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      autoRefreshOnStartup: autoRefreshOnStartup ?? this.autoRefreshOnStartup,
      customFields: customFields ?? this.customFields,
      fallbackDomains: fallbackDomains ?? this.fallbackDomains,
      fallbackDomainsUrl: fallbackDomainsUrl ?? this.fallbackDomainsUrl,
      domainTimeoutMs: domainTimeoutMs ?? this.domainTimeoutMs,
      root: root ?? this.root,
    );
  }
}
