import 'dart:convert';

import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import 'import_result.dart';

/// Разбирает xray-core JSON-подписку в [SubscriptionImportResult]. Панели
/// отдают либо один конфиг-объект, либо массив таких объектов (по одному на
/// сервер, с полем `remarks` как именем) — оба варианта поддерживаются.
/// Протоколы, отличные от VLESS (`hysteria`, ...), попадают в `skipped`.
SubscriptionImportResult parseXraySubscription(String rawJson) {
  final decoded = jsonDecode(rawJson);
  final configs = decoded is List ? decoded : [decoded];

  final servers = <ImportedServer>[];
  final skipped = <ImportSkipped>[];

  for (final entry in configs) {
    final map = entry as Map<String, dynamic>;
    final name = map['remarks'] as String? ?? map['ps'] as String? ?? 'Server';
    final outbounds = ((map['outbounds'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final proxyOutbound = outbounds
        .where((o) => o['protocol'] != 'freedom' && o['protocol'] != 'blackhole')
        .firstOrNull;

    if (proxyOutbound == null) {
      skipped.add(
        ImportSkipped(label: name, reason: 'Не найден outbound с прокси'),
      );
      continue;
    }

    final protocol = proxyOutbound['protocol'] as String?;
    if (protocol != 'vless' && protocol != 'hysteria') {
      skipped.add(
        ImportSkipped(
          label: name,
          reason: 'Протокол $protocol пока не поддерживается',
        ),
      );
      continue;
    }

    try {
      final config = protocol == 'vless'
          ? _parseVlessOutbound(proxyOutbound)
          : _parseHysteriaOutbound(proxyOutbound);
      final routingRules = _parseRoutingRules(map['routing']);
      servers.add(
        ImportedServer(name: name, config: config, routingRules: routingRules),
      );
    } on FormatException catch (e) {
      skipped.add(ImportSkipped(label: name, reason: e.message));
    }
  }

  return SubscriptionImportResult(servers: servers, skipped: skipped);
}

VlessConfig _parseVlessOutbound(Map<String, dynamic> outbound) {
  final settings = outbound['settings'] as Map<String, dynamic>;
  final vnext = (settings['vnext'] as List).first as Map<String, dynamic>;
  final user = (vnext['users'] as List).first as Map<String, dynamic>;

  final streamSettings =
      outbound['streamSettings'] as Map<String, dynamic>? ?? const {};
  final networkParam =
      (streamSettings['method'] ?? streamSettings['network']) as String? ??
      'tcp';
  final network = switch (networkParam) {
    'tcp' || 'raw' => VlessNetwork.tcp,
    'xhttp' || 'splithttp' => VlessNetwork.xhttp,
    _ => throw FormatException('Неподдерживаемый транспорт: $networkParam'),
  };

  final securityParam = streamSettings['security'] as String? ?? 'none';
  final security = switch (securityParam) {
    'none' => VlessSecurity.none,
    'tls' => VlessSecurity.tls,
    'reality' => VlessSecurity.reality,
    _ => throw FormatException('Неподдерживаемый security: $securityParam'),
  };

  final realitySettings =
      streamSettings['realitySettings'] as Map<String, dynamic>?;
  final tlsSettings = streamSettings['tlsSettings'] as Map<String, dynamic>?;
  // Xray accepts different casing of JSON field names, including
  // xHTTPSettings emitted by some subscription providers.
  final xhttpSettings = network == VlessNetwork.xhttp
      ? _xhttpSettings(streamSettings)
      : null;
  final xhttpExtra = xhttpSettings == null
      ? null
      : (Map<String, dynamic>.of(xhttpSettings)
          ..remove('path')
          ..remove('host')
          ..remove('mode'));

  return VlessConfig(
    address: vnext['address'] as String,
    port: vnext['port'] as int,
    uuid: user['id'] as String,
    flow: user['flow'] as String?,
    network: network,
    security: security,
    sni:
        (realitySettings?['serverName'] ?? tlsSettings?['serverName'])
            as String?,
    publicKey:
        (realitySettings?['password'] ?? realitySettings?['publicKey'])
            as String?,
    shortId: realitySettings?['shortId'] as String?,
    fingerprint:
        (realitySettings?['fingerprint'] ?? tlsSettings?['fingerprint'])
            as String?,
    xhttpPath: xhttpSettings?['path'] as String?,
    xhttpHost: xhttpSettings?['host'] as String?,
    xhttpMode: xhttpSettings?['mode'] as String?,
    xhttpExtra: xhttpExtra?.isEmpty == false ? xhttpExtra : null,
    pinnedPeerCertSha256: tlsSettings?['pinnedPeerCertSha256'] as String?,
    verifyPeerCertByName: tlsSettings?['verifyPeerCertByName'] as String?,
    alpn: switch (tlsSettings?['alpn']) {
      String protocol => [protocol],
      List protocols => protocols.cast<String>(),
      _ => null,
    },
  );
}

Map<String, dynamic>? _xhttpSettings(Map<String, dynamic> streamSettings) {
  Map<String, dynamic>? splitHttp;
  for (final entry in streamSettings.entries) {
    final key = entry.key.toLowerCase();
    if (key == 'xhttpsettings' && entry.value != null) {
      return entry.value as Map<String, dynamic>;
    }
    if (key == 'splithttpsettings') {
      splitHttp = entry.value as Map<String, dynamic>?;
    }
  }
  return splitHttp;
}

Hysteria2Config _parseHysteriaOutbound(Map<String, dynamic> outbound) {
  final settings = outbound['settings'] as Map<String, dynamic>;
  final streamSettings =
      outbound['streamSettings'] as Map<String, dynamic>? ?? const {};
  final tlsSettings = streamSettings['tlsSettings'] as Map<String, dynamic>?;
  final hysteriaSettings =
      streamSettings['hysteriaSettings'] as Map<String, dynamic>? ?? const {};

  return Hysteria2Config(
    address: settings['address'] as String,
    port: settings['port'] as int,
    auth: hysteriaSettings['auth'] as String,
    sni: tlsSettings?['serverName'] as String?,
    insecure: tlsSettings?['allowInsecure'] as bool? ?? false,
    pinnedPeerCertSha256: tlsSettings?['pinnedPeerCertSha256'] as String?,
    verifyPeerCertByName: tlsSettings?['verifyPeerCertByName'] as String?,
    obfsPassword: _parseSalamanderPassword(streamSettings),
  );
}

/// Salamander в подписках (проверено на живом `?format=xray` от
/// getmagix.cc) приходит как `streamSettings.finalmask.udp[].settings.password`
/// — та же актуальная схема Xray-core, что и в `xray_config_mapper.dart`
/// (`_hysteria2Outbound`), не устаревший `hysteriaSettings.obfs`.
String? _parseSalamanderPassword(Map<String, dynamic> streamSettings) {
  final finalMask = streamSettings['finalmask'] as Map<String, dynamic>?;
  final udpMasks = finalMask?['udp'] as List?;
  if (udpMasks == null) return null;
  for (final mask in udpMasks) {
    if (mask is Map && mask['type'] == 'salamander') {
      final maskSettings = mask['settings'] as Map<String, dynamic>?;
      final password = maskSettings?['password'] as String?;
      if (password != null) return password;
    }
  }
  return null;
}

/// Разбирает xray-шный блок `"routing"."rules"` (массив объектов
/// `{"type": "field", "domain": [...], "outboundTag": ...}` /
/// `{"type": "field", "ip": [...], "outboundTag": ...}`) в [RoutingRule].
/// Значения (в т.ч. `geosite:`/`geoip:`-префиксы) сохраняются как есть, без
/// интерпретации — см. ROADMAP.md, трек 3.
List<RoutingRule> _parseRoutingRules(dynamic routing) {
  if (routing is! Map<String, dynamic>) return const [];
  final rulesJson = routing['rules'] as List? ?? const [];

  final rules = <RoutingRule>[];
  for (final entry in rulesJson) {
    final rule = entry as Map<String, dynamic>;
    final outboundTag = rule['outboundTag'] as String?;
    if (outboundTag == null) continue;

    final domain = rule['domain'] as List?;
    if (domain != null && domain.isNotEmpty) {
      rules.add(
        DomainRule(values: domain.cast<String>(), outboundTag: outboundTag),
      );
    }

    final ip = rule['ip'] as List?;
    if (ip != null && ip.isNotEmpty) {
      rules.add(IpRule(values: ip.cast<String>(), outboundTag: outboundTag));
    }
  }
  return rules;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
