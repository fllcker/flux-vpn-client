import '../../core_abstraction/server_config.dart';

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
    throw const VlessLinkFormatException('Ссылка должна начинаться с vless://');
  }

  final uuid = uri.userInfo;
  if (uuid.isEmpty) {
    throw const VlessLinkFormatException('В ссылке отсутствует UUID');
  }

  final host = uri.host;
  final port = uri.port;
  if (host.isEmpty || port == 0) {
    throw const VlessLinkFormatException('В ссылке отсутствует адрес или порт');
  }

  final params = uri.queryParameters;

  final networkParam = params['type'] ?? 'tcp';
  final network = switch (networkParam) {
    'tcp' => VlessNetwork.tcp,
    'xhttp' => VlessNetwork.xhttp,
    _ => throw VlessLinkFormatException('Неподдерживаемый транспорт: $networkParam'),
  };

  final securityParam = params['security'] ?? 'none';
  final security = switch (securityParam) {
    'none' => VlessSecurity.none,
    'tls' => VlessSecurity.tls,
    'reality' => VlessSecurity.reality,
    _ => throw VlessLinkFormatException('Неподдерживаемый security: $securityParam'),
  };

  final flow = params['flow'];
  final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : host;

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
      xhttpPath: params['path'],
      xhttpHost: params['host'],
    ),
  );
}
