import 'dart:convert';

import '../../core_abstraction/server_config.dart';
import '../../l10n/strings.dart';

class ParsedVlessLink {
  final String name;
  final VlessConfig config;

  const ParsedVlessLink({required this.name, required this.config});
}

class VlessLinkFormatException implements Exception {
  final String message;
  const VlessLinkFormatException(this.message);

  @override
  String toString() => message;
}

/// Парсит `vless://uuid@host:port?params#name` в [ParsedVlessLink].
/// Поддерживает только то, что умеет [VlessConfig] сейчас — `type`=tcp/xhttp,
/// `security`=none/tls/reality; остальное считается ошибкой формата.
ParsedVlessLink parseVlessLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'vless') {
    throw VlessLinkFormatException(S.vlessLinkMustStartWith);
  }

  final uuid = uri.userInfo;
  if (uuid.isEmpty) {
    throw VlessLinkFormatException(S.linkMissingUuid);
  }

  final host = uri.host;
  final port = uri.port;
  if (host.isEmpty || port == 0) {
    throw VlessLinkFormatException(S.linkMissingAddressOrPort);
  }

  final params = uri.queryParameters;

  final networkParam = params['type'] ?? 'tcp';
  final network = switch (networkParam) {
    'tcp' || 'raw' => VlessNetwork.tcp,
    'xhttp' || 'splithttp' => VlessNetwork.xhttp,
    _ => throw VlessLinkFormatException(S.unsupportedTransport(networkParam)),
  };

  final securityParam = params['security'] ?? 'none';
  final security = switch (securityParam) {
    'none' => VlessSecurity.none,
    'tls' => VlessSecurity.tls,
    'reality' => VlessSecurity.reality,
    _ => throw VlessLinkFormatException(S.unsupportedSecurity(securityParam)),
  };

  final flow = params['flow'];
  final name = uri.fragment.isNotEmpty
      ? Uri.decodeComponent(uri.fragment)
      : host;
  final isXhttp = network == VlessNetwork.xhttp;

  return ParsedVlessLink(
    name: name,
    config: VlessConfig(
      address: host,
      port: port,
      uuid: uuid,
      flow: (flow != null && flow.isNotEmpty) ? flow : null,
      network: network,
      security: security,
      sni: params['sni'],
      publicKey: params['pbk'],
      shortId: params['sid'],
      fingerprint: params['fp'],
      pinnedPeerCertSha256: params['pcs'],
      verifyPeerCertByName: params['vcn'],
      xhttpPath: isXhttp ? params['path'] : null,
      xhttpHost: isXhttp ? params['host'] : null,
      xhttpMode: isXhttp ? params['mode'] : null,
      xhttpExtra: isXhttp ? _parseXhttpExtra(params['extra']) : null,
      alpn: params['alpn']
          ?.split(',')
          .where((value) => value.isNotEmpty)
          .toList(),
    ),
  );
}

Map<String, dynamic>? _parseXhttpExtra(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Report malformed JSON and non-object values with the same import error.
  }
  throw VlessLinkFormatException(S.invalidXhttpExtra);
}
