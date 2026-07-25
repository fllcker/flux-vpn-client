import '../../core_abstraction/server_config.dart';
import '../../l10n/strings.dart';

class ParsedHysteria2Link {
  final String name;
  final Hysteria2Config config;

  const ParsedHysteria2Link({required this.name, required this.config});
}

class Hysteria2LinkFormatException implements Exception {
  final String message;
  const Hysteria2LinkFormatException(this.message);

  @override
  String toString() => message;
}

/// Парсит `hysteria2://auth@host:port/?insecure=1&obfs=salamander&obfs-password=...&sni=...#name`
/// (алиас схемы — `hy2://`). `obfs`/`obfs-password` включают Salamander
/// только если оба параметра присутствуют — сервер без обфускации просто не
/// шлёт ни один из них.
ParsedHysteria2Link parseHysteria2Link(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || (uri.scheme != 'hysteria2' && uri.scheme != 'hy2')) {
    throw Hysteria2LinkFormatException(S.hysteria2LinkMustStartWith);
  }

  final auth = uri.userInfo;
  if (auth.isEmpty) {
    throw Hysteria2LinkFormatException(S.linkMissingPassword);
  }

  final host = uri.host;
  final port = uri.port;
  if (host.isEmpty || port == 0) {
    throw Hysteria2LinkFormatException(S.linkMissingAddressOrPort);
  }

  final params = uri.queryParameters;
  final obfsType = params['obfs'];
  final obfsPassword = params['obfs-password'];
  final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : host;

  return ParsedHysteria2Link(
    name: name,
    config: Hysteria2Config(
      address: host,
      port: port,
      auth: auth,
      sni: params['sni'],
      insecure: params['insecure'] == '1' || params['insecure'] == 'true',
      obfsPassword:
          (obfsType != null && obfsType.isNotEmpty && obfsPassword != null && obfsPassword.isNotEmpty)
              ? obfsPassword
              : null,
    ),
  );
}
