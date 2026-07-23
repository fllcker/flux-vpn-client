/// Протокол/транспорт-специфичные параметры одного [ConnectionVariant].
/// Базовый маркер — реализации (VLESS, Hysteria2, ...) добавляются по мере
/// поддержки протоколов и знают, как себя экспортировать в конфиг
/// конкретного [CoreEngine].
sealed class ServerConfig {
  const ServerConfig();
}

enum VlessNetwork { tcp, xhttp }

enum VlessSecurity { none, tls, reality }

/// Параметры VLESS-сервера — первый поддерживаемый протокол (см. PLAN.md,
/// "Ядро №1: xray-core").
class VlessConfig extends ServerConfig {
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
  });
}
