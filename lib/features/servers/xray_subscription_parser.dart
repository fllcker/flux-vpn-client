import 'dart:convert';

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
    if (protocol != 'vless') {
      skipped.add(
        ImportSkipped(
          label: name,
          reason: 'Протокол $protocol пока не поддерживается',
        ),
      );
      continue;
    }

    try {
      servers.add(
        ImportedServer(name: name, config: _parseVlessOutbound(proxyOutbound)),
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
  final networkParam = streamSettings['network'] as String? ?? 'tcp';
  final network = switch (networkParam) {
    'tcp' => VlessNetwork.tcp,
    'xhttp' => VlessNetwork.xhttp,
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
  final xhttpSettings = streamSettings['xhttpSettings'] as Map<String, dynamic>?;

  return VlessConfig(
    address: vnext['address'] as String,
    port: vnext['port'] as int,
    uuid: user['id'] as String,
    flow: user['flow'] as String?,
    network: network,
    security: security,
    sni: (realitySettings?['serverName'] ?? tlsSettings?['serverName']) as String?,
    publicKey: realitySettings?['publicKey'] as String?,
    shortId: realitySettings?['shortId'] as String?,
    fingerprint:
        (realitySettings?['fingerprint'] ?? tlsSettings?['fingerprint'])
            as String?,
    xhttpPath: xhttpSettings?['path'] as String?,
    xhttpHost: xhttpSettings?['host'] as String?,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
