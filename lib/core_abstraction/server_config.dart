/// Протокол/транспорт-специфичные параметры одного [ConnectionVariant].
/// Базовый маркер — реализации (VLESS, Hysteria2, ...) добавляются по мере
/// поддержки протоколов и знают, как себя экспортировать в конфиг
/// конкретного [CoreEngine] и (де)сериализовать в Magic JSON.
sealed class ServerConfig {
  const ServerConfig();

  /// Адрес хоста — общий для всех протоколов, единственный стабильный
  /// идентификатор физического сервера (используется, например, для
  /// сопоставления вариантов в один [ConnectionVariant]-набор и для мержа
  /// состояния при рефреше подписки, см. `merge_subscription_tree.dart`).
  String get address;

  Map<String, dynamic> toJson();

  /// Диспетчер по полю `protocol`. Незнакомый протокол — ошибка формата, а
  /// не тихий пропуск: без него [ConnectionVariant] нечем подключаться.
  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    final protocol = json['protocol'] as String?;
    return switch (protocol) {
      'vless' => VlessConfig.fromJson(json),
      'hysteria2' => Hysteria2Config.fromJson(json),
      _ => throw FormatException('Unknown ServerConfig.protocol: $protocol'),
    };
  }
}

enum VlessNetwork { tcp, xhttp }

enum VlessSecurity { none, tls, reality }

/// Параметры VLESS-сервера — первый поддерживаемый протокол (см. PLAN.md,
/// "Ядро №1: xray-core").
class VlessConfig extends ServerConfig {
  @override
  final String address;
  final int port;
  final String uuid;
  final String? flow;
  final VlessNetwork network;
  final VlessSecurity security;

  // TLS / Reality
  final String? sni;
  final String? publicKey;
  final String? shortId;
  final String? fingerprint;

  // xhttp-транспорт
  final String? xhttpPath;
  final String? xhttpHost;

  const VlessConfig({
    required this.address,
    required this.port,
    required this.uuid,
    this.flow,
    this.network = VlessNetwork.tcp,
    this.security = VlessSecurity.none,
    this.sni,
    this.publicKey,
    this.shortId,
    this.fingerprint,
    this.xhttpPath,
    this.xhttpHost,
  });

  factory VlessConfig.fromJson(Map<String, dynamic> json) {
    return VlessConfig(
      address: json['address'] as String,
      port: json['port'] as int,
      uuid: json['uuid'] as String,
      flow: json['flow'] as String?,
      network: VlessNetwork.values.byName(json['network'] as String? ?? 'tcp'),
      security: VlessSecurity.values.byName(
        json['security'] as String? ?? 'none',
      ),
      sni: json['sni'] as String?,
      publicKey: json['publicKey'] as String?,
      shortId: json['shortId'] as String?,
      fingerprint: json['fingerprint'] as String?,
      xhttpPath: json['xhttpPath'] as String?,
      xhttpHost: json['xhttpHost'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'protocol': 'vless',
    'address': address,
    'port': port,
    'uuid': uuid,
    if (flow != null) 'flow': flow,
    'network': network.name,
    'security': security.name,
    if (sni != null) 'sni': sni,
    if (publicKey != null) 'publicKey': publicKey,
    if (shortId != null) 'shortId': shortId,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (xhttpPath != null) 'xhttpPath': xhttpPath,
    if (xhttpHost != null) 'xhttpHost': xhttpHost,
  };
}

/// Параметры Hysteria2-сервера (xray-core называет протокол `hysteria`,
/// `version: 2` — см. `xray_config_mapper.dart`). Обфускация Salamander —
/// опциональна: `obfsPassword == null` значит "без обфускации", непустая
/// строка — включает `obfs: {type: "salamander", password: ...}`.
class Hysteria2Config extends ServerConfig {
  @override
  final String address;
  final int port;
  final String auth;
  final String? sni;
  final bool insecure;
  final String? obfsPassword;

  const Hysteria2Config({
    required this.address,
    required this.port,
    required this.auth,
    this.sni,
    this.insecure = false,
    this.obfsPassword,
  });

  factory Hysteria2Config.fromJson(Map<String, dynamic> json) {
    return Hysteria2Config(
      address: json['address'] as String,
      port: json['port'] as int,
      auth: json['auth'] as String,
      sni: json['sni'] as String?,
      insecure: json['insecure'] as bool? ?? false,
      obfsPassword: json['obfsPassword'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'protocol': 'hysteria2',
    'address': address,
    'port': port,
    'auth': auth,
    if (sni != null) 'sni': sni,
    if (insecure) 'insecure': insecure,
    if (obfsPassword != null) 'obfsPassword': obfsPassword,
  };
}
