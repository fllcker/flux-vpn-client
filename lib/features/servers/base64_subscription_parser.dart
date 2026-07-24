import 'dart:convert';

import 'hysteria2_link_parser.dart';
import 'import_result.dart';
import 'vless_link_parser.dart';

/// Разбирает тело base64-подписки (список ссылок вида `vless://...`/
/// `hysteria2://...`, по одной на строку, целиком закодированный в
/// base64/base64url) в [SubscriptionImportResult]. Остальные схемы
/// (`ss://`, `trojan://`, ...) попадают в `skipped`.
SubscriptionImportResult parseBase64Subscription(String body) {
  final decoded = _decodeBody(body);
  final lines = decoded
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  final servers = <ImportedServer>[];
  final skipped = <ImportSkipped>[];

  for (final line in lines) {
    if (line.startsWith('vless://')) {
      try {
        final parsed = parseVlessLink(line);
        servers.add(ImportedServer(name: parsed.name, config: parsed.config));
      } on VlessLinkFormatException catch (e) {
        skipped.add(ImportSkipped(label: line, reason: e.message));
      }
      continue;
    }

    if (line.startsWith('hysteria2://') || line.startsWith('hy2://')) {
      try {
        final parsed = parseHysteria2Link(line);
        servers.add(ImportedServer(name: parsed.name, config: parsed.config));
      } on Hysteria2LinkFormatException catch (e) {
        skipped.add(ImportSkipped(label: line, reason: e.message));
      }
      continue;
    }

    final scheme = line.contains('://') ? line.split('://').first : line;
    skipped.add(
      ImportSkipped(
        label: scheme,
        reason: 'Протокол $scheme:// пока не поддерживается',
      ),
    );
  }

  return SubscriptionImportResult(servers: servers, skipped: skipped);
}

/// Некоторые панели отдают подписку без base64-обёртки (обычный текст со
/// ссылками) — в этом случае декодирование падает, и тело используется как
/// есть.
String _decodeBody(String body) {
  final trimmed = body.trim();
  final normalized = trimmed.replaceAll('-', '+').replaceAll('_', '/');
  final padLength = (4 - normalized.length % 4) % 4;
  final padded = normalized + ('=' * padLength);

  try {
    return utf8.decode(base64.decode(padded));
  } on FormatException {
    return trimmed;
  }
}
