import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/subscription.dart';
import 'base64_subscription_parser.dart';
import 'import_result.dart';
import 'import_to_proxy_nodes.dart';
import 'vless_link_parser.dart';
import 'xray_subscription_parser.dart';

const _uuid = Uuid();

/// Что получилось из вставленной ссылки: либо один сервер (обычная
/// `vless://` ссылка — добавляется как есть, без подписки), либо подписка
/// (скачана по http(s):// URL, может содержать несколько серверов и часть
/// из них может быть пропущена как неподдерживаемая).
sealed class LinkImportResult {
  const LinkImportResult();
}

class SingleServerImportResult extends LinkImportResult {
  final ServerLeaf leaf;
  const SingleServerImportResult(this.leaf);
}

class SubscriptionImportResultOk extends LinkImportResult {
  final Subscription subscription;
  final List<ImportSkipped> skipped;
  const SubscriptionImportResultOk(this.subscription, this.skipped);
}

class LinkImportFailure extends LinkImportResult {
  final String reason;
  const LinkImportFailure(this.reason);
}

/// Разбирает то, что пользователь вставил в поле "Добавить сервер" — как
/// делают остальные клиенты, это всегда ссылка: либо `vless://...`, либо
/// http(s):// адрес подписки.
Future<LinkImportResult> importLink(String rawInput) async {
  final link = rawInput.trim();

  if (link.startsWith('vless://')) {
    try {
      final parsed = parseVlessLink(link);
      final leaves = importedServersToLeaves([
        ImportedServer(name: parsed.name, config: parsed.config),
      ]);
      return SingleServerImportResult(leaves.single);
    } on VlessLinkFormatException catch (e) {
      return LinkImportFailure(e.message);
    }
  }

  if (!link.startsWith('http://') && !link.startsWith('https://')) {
    return const LinkImportFailure(
      'Ожидается ссылка: vless://... или http(s)://ссылка-на-подписку',
    );
  }

  final String body;
  try {
    final response = await http.get(Uri.parse(link));
    if (response.statusCode != 200) {
      return LinkImportFailure(
        'Не удалось скачать подписку: HTTP ${response.statusCode}',
      );
    }
    body = response.body;
  } catch (e) {
    return LinkImportFailure('Не удалось скачать подписку: $e');
  }

  final trimmedBody = body.trim();
  final parsed = trimmedBody.startsWith('{') || trimmedBody.startsWith('[')
      ? _tryParseXray(trimmedBody)
      : parseBase64Subscription(trimmedBody);

  if (parsed.servers.isEmpty) {
    return const LinkImportFailure(
      'В подписке не нашлось ни одного поддерживаемого сервера',
    );
  }

  final leaves = importedServersToLeaves(parsed.servers);
  final name = Uri.tryParse(link)?.host ?? 'Подписка';

  final subscription = Subscription(
    id: _uuid.v4(),
    name: name,
    url: link,
    lastRefreshedAt: DateTime.now(),
    root: ServerGroup(id: _uuid.v4(), name: name, children: leaves),
  );

  return SubscriptionImportResultOk(subscription, parsed.skipped);
}

SubscriptionImportResult _tryParseXray(String body) {
  try {
    return parseXraySubscription(body);
  } on FormatException catch (e) {
    return SubscriptionImportResult(
      servers: const [],
      skipped: [ImportSkipped(label: 'xray-json', reason: e.message)],
    );
  }
}
