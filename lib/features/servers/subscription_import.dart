import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core_abstraction/mj_payload.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/subscription.dart';
import '../../l10n/strings.dart';
import 'base64_subscription_parser.dart';
import 'group_leaves_by_name.dart';
import 'hysteria2_link_parser.dart';
import 'import_result.dart';
import 'import_to_proxy_nodes.dart';
import 'insert_auto_select_markers.dart';
import 'merge_subscription_tree.dart';
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

/// URL отдал Magic JSON напрямую (см. `core_abstraction/mj_payload.dart`,
/// docs/magic_json.md) вместо xray-json/base64-подписки — сервис-генератор,
/// который знает про Flux, может прислать уже готовые `Subscription`/
/// `ProxyNode` вместо конвертации в чужой формат и обратно.
class MjImportResultOk extends LinkImportResult {
  final MjPayload payload;
  const MjImportResultOk(this.payload);
}

class LinkImportFailure extends LinkImportResult {
  final String reason;
  const LinkImportFailure(this.reason);
}

/// Подтип [LinkImportFailure] — конкретно "домен недоступен" (DNS resolve
/// failure, connection refused, таймаут), а не обычная ошибка сервера
/// (4xx/5xx, которая означает, что домен как раз жив). Только на этот
/// подтип реагирует фоллбек на альтернативные домены подписки —
/// см. [refreshSubscription], ROADMAP.md трек 23.
class DomainUnavailableFailure extends LinkImportFailure {
  const DomainUnavailableFailure(super.reason);
}

const _defaultDomainTimeout = Duration(milliseconds: 2500);

/// Разбирает то, что пользователь вставил в поле "Добавить сервер" — как
/// делают остальные клиенты, это всегда ссылка: либо `vless://...`/
/// `hysteria2://...`(`hy2://`), либо http(s):// адрес подписки.
Future<LinkImportResult> importLink(
  String rawInput, {
  bool autoGroup = true,
  Duration timeout = _defaultDomainTimeout,
  http.Client? client,
}) async {
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

  if (link.startsWith('hysteria2://') || link.startsWith('hy2://')) {
    try {
      final parsed = parseHysteria2Link(link);
      final leaves = importedServersToLeaves([
        ImportedServer(name: parsed.name, config: parsed.config),
      ]);
      return SingleServerImportResult(leaves.single);
    } on Hysteria2LinkFormatException catch (e) {
      return LinkImportFailure(e.message);
    }
  }

  if (!link.startsWith('http://') && !link.startsWith('https://')) {
    return LinkImportFailure(S.expectedLinkError);
  }

  final String body;
  final http.Response response;
  try {
    response = await (client?.get(Uri.parse(link)) ?? http.get(Uri.parse(link)))
        .timeout(timeout);
    if (response.statusCode != 200) {
      return LinkImportFailure(S.downloadFailedHttp(response.statusCode));
    }
    body = response.body;
  } on SocketException catch (e) {
    return DomainUnavailableFailure(S.downloadFailedGeneric(e));
  } on TimeoutException catch (e) {
    return DomainUnavailableFailure(S.downloadFailedGeneric(e));
  } catch (e) {
    return LinkImportFailure(S.downloadFailedGeneric(e));
  }

  final trimmedBody = body.trim();

  // Magic JSON — проверяем раньше xray-json: оба формата начинаются с `{`,
  // но MJ-конверт узнаётся по `schemaVersion`/`type` на верхнем уровне,
  // которых у xray-json (`remarks`/`outbounds`) нет.
  if (trimmedBody.startsWith('{')) {
    final decoded = _tryDecodeJsonObject(trimmedBody);
    if (decoded != null && MjPayload.looksLikePayload(decoded)) {
      try {
        return MjImportResultOk(MjPayload.fromJson(decoded));
      } on FormatException catch (e) {
        return LinkImportFailure(S.invalidMagicJson(e.message));
      }
    }
  }

  final parsed = trimmedBody.startsWith('{') || trimmedBody.startsWith('[')
      ? _tryParseXray(trimmedBody)
      : parseBase64Subscription(trimmedBody);

  if (parsed.servers.isEmpty) {
    return LinkImportFailure(S.noSupportedServersFound);
  }

  final leaves = importedServersToLeaves(parsed.servers);
  final name = Uri.tryParse(link)?.host ?? S.defaultSubscriptionName;
  final userinfo = _parseSubscriptionUserinfo(response.headers);
  final announce = _parseAnnounce(response.headers);
  final customFields = _parseCustomFields(response.headers);

  final subscription = Subscription(
    id: _uuid.v4(),
    name: name,
    url: link,
    annotation: announce,
    traffic: userinfo?.traffic,
    expiresAt: userinfo?.expiresAt,
    lastRefreshedAt: DateTime.now(),
    customFields: customFields,
    root: insertAutoSelectMarkers(
      ServerGroup(
        id: _uuid.v4(),
        name: name,
        children: autoGroup ? groupLeavesByName(leaves) : leaves,
      ),
    ),
  );

  return SubscriptionImportResultOk(subscription, parsed.skipped);
}

/// Перекачивает [subscription.url] заново и возвращает обновлённую
/// подписку с тем же [Subscription.id] (и настройками вроде
/// [Subscription.autoRefreshOnStartup]) — используется и кнопкой "Обновить"
/// на странице подписки, и автообновлением при запуске.
///
/// [resetOrder] переключает стратегию слияния дерева: по умолчанию
/// (`false`) сохраняется текущий порядок/группировка, в т.ч. ручная
/// drag-and-drop сортировка (см. [mergeSubscriptionTree]); `true` —
/// используется кнопкой "Сбросить сортировку" на странице подписки, чтобы
/// пересобрать дерево заново из источника (см. [resetSubscriptionOrder]).
Future<LinkImportResult> refreshSubscription(
  Subscription subscription, {
  bool autoGroup = true,
  bool resetOrder = false,
  http.Client? client,
}) async {
  final timeout = Duration(milliseconds: subscription.domainTimeoutMs);
  var result = await importLink(
    subscription.url,
    autoGroup: autoGroup,
    timeout: timeout,
    client: client,
  );
  var fetchedFallbackDomains = subscription.fallbackDomains;
  // Не `null`, только если реально сработал фоллбек — тогда именно этот url
  // (а не то, что скажет тело ответа) должен стать новым `Subscription.url`.
  // Для xray-json/base64-источников `fetched.url` и так совпадает с ним
  // (`importLink` кладёт туда `link` как есть), но для MJ `content` присылает
  // свой собственный `url` в JSON — сервис может не знать/не обновить его
  // под адрес зеркала, поэтому не полагаемся на тело ответа в этом случае.
  String? workingUrl;

  // Домен основного url недоступен (DNS/connect/timeout — не обычная
  // ошибка сервера) — перебираем фоллбек-домены подписки, см.
  // ROADMAP.md, трек 23. Не срабатывает на первичном импорте — там этот
  // код не вызывается вовсе, `Subscription` с фоллбек-секцией на этот
  // момент уже должна существовать локально с прошлого успешного фетча.
  if (result is DomainUnavailableFailure) {
    final fallback = await _tryFallbackDomains(
      subscription,
      autoGroup: autoGroup,
      timeout: timeout,
      client: client,
    );
    if (fallback != null) {
      result = fallback.result;
      workingUrl = fallback.url;
      if (fallback.fetchedDomains != null) {
        fetchedFallbackDomains = fallback.fetchedDomains!;
      }
    }
  }

  // URL, добавленный как MJ 'subscriptions', продолжает возвращать тот же
  // конверт на рефреше (сервис — источник правды, не xray-json) — находим
  // в присланном наборе элемент с тем же id, что и у обновляемой подписки,
  // и просто дальше идём общим путём слияния дерева (merge/reset), как если
  // бы это был обычный `SubscriptionImportResultOk`. Остальные подписки из
  // того же конверта (если сервис прислал сразу несколько) молча
  // игнорируются здесь — точечный рефреш трогает только ту, что попросили.
  if (result case MjImportResultOk(payload: MjSubscriptionsPayload(:final subscriptions))) {
    final match = subscriptions.where((s) => s.id == subscription.id).firstOrNull;
    if (match == null) {
      return LinkImportFailure(S.subscriptionNoLongerInMj);
    }
    return _mergeSubscription(
      subscription,
      match,
      const [],
      resetOrder: resetOrder,
      fallbackDomains: fetchedFallbackDomains,
      urlOverride: workingUrl,
    );
  }
  if (result is MjImportResultOk) {
    return LinkImportFailure(S.urlNowReturnsMjNodes);
  }

  if (result is! SubscriptionImportResultOk) return result;

  final fetched = result.subscription;
  return _mergeSubscription(
    subscription,
    fetched,
    result.skipped,
    resetOrder: resetOrder,
    fallbackDomains: fetchedFallbackDomains,
    urlOverride: workingUrl,
  );
}

/// Результат успешного фоллбека — либо статический домен подошёл сразу,
/// либо после фетча JSON-списка по [Subscription.fallbackDomainsUrl].
/// [fetchedDomains] — не `null`, только если в этом заходе реально
/// выполнялся JSON-фетч (даже если сам список оказался пустым) — так
/// `refreshSubscription` знает, нужно ли заменить сохранённый статический
/// список свежим.
class _FallbackAttempt {
  final LinkImportResult result;
  final String url;
  final List<String>? fetchedDomains;
  const _FallbackAttempt(this.result, this.url, this.fetchedDomains);
}

/// Перебирает [Subscription.fallbackDomains] по порядку, заменяя только
/// хост в [Subscription.url] и оставляя path/query как есть; если список
/// исчерпан и задан [Subscription.fallbackDomainsUrl] — фетчит его
/// (`{"domains": [...]}`) и перебирает уже этот список. Останавливается на
/// первом домене, для которого `importLink` не вернул
/// [DomainUnavailableFailure] (реальная ошибка сервера на фоллбек-домене —
/// это не "домен недоступен", останавливаемся и на ней, а не пробуем
/// дальше).
Future<_FallbackAttempt?> _tryFallbackDomains(
  Subscription subscription, {
  required bool autoGroup,
  required Duration timeout,
  http.Client? client,
}) async {
  Future<_FallbackAttempt?> tryDomains(
    List<String> domains,
    List<String>? fetchedDomains,
  ) async {
    for (final domain in domains) {
      final candidateUrl = _withHost(subscription.url, domain);
      if (candidateUrl == null) continue;
      final result = await importLink(
        candidateUrl,
        autoGroup: autoGroup,
        timeout: timeout,
        client: client,
      );
      if (result is! DomainUnavailableFailure) {
        return _FallbackAttempt(result, candidateUrl, fetchedDomains);
      }
    }
    return null;
  }

  final staticAttempt = await tryDomains(subscription.fallbackDomains, null);
  if (staticAttempt != null) return staticAttempt;

  final fallbackDomainsUrl = subscription.fallbackDomainsUrl;
  if (fallbackDomainsUrl == null) return null;

  final fetchedDomains = await _fetchFallbackDomainsList(
    fallbackDomainsUrl,
    timeout,
    client,
  );
  if (fetchedDomains == null) return null;

  return tryDomains(fetchedDomains, fetchedDomains);
}

String? _withHost(String url, String host) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  try {
    return uri.replace(host: host).toString();
  } on FormatException {
    return null;
  }
}

/// Фетчит `{"domains": ["example2.com", ...]}` — best-effort: любая ошибка
/// (сеть, формат) означает "дополнительных доменов нет", не пробрасывается
/// наружу как ошибка рефреша в целом.
Future<List<String>?> _fetchFallbackDomainsList(
  String url,
  Duration timeout,
  http.Client? client,
) async {
  try {
    final response = await (client?.get(Uri.parse(url)) ?? http.get(Uri.parse(url)))
        .timeout(timeout);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['domains'] is! List) return null;
    return (decoded['domains'] as List).map((v) => v.toString()).toList();
  } catch (_) {
    return null;
  }
}

LinkImportResult _mergeSubscription(
  Subscription subscription,
  Subscription fetched,
  List<ImportSkipped> skipped, {
  required bool resetOrder,
  required List<String> fallbackDomains,
  String? urlOverride,
}) {
  final root = resetOrder
      ? resetSubscriptionOrder(subscription.root, fetched.root)
      : mergeSubscriptionTree(subscription.root, fetched.root);
  final merged = Subscription(
    id: subscription.id,
    name: fetched.name,
    url: urlOverride ?? fetched.url,
    pictureUrl: fetched.pictureUrl,
    annotation: fetched.annotation,
    traffic: fetched.traffic,
    expiresAt: fetched.expiresAt,
    lastRefreshedAt: fetched.lastRefreshedAt,
    autoRefreshOnStartup: subscription.autoRefreshOnStartup,
    customFields: fetched.customFields,
    fallbackDomains: fallbackDomains,
    fallbackDomainsUrl: fetched.fallbackDomainsUrl ?? subscription.fallbackDomainsUrl,
    domainTimeoutMs: fetched.domainTimeoutMs,
    root: root,
  );
  return SubscriptionImportResultOk(merged, skipped);
}

/// Ищет подписку с идентичным (посимвольно) URL — так можно держать в
/// списке `example.com/?preset=1` и `example.com/?preset=2` отдельно, но
/// повторный импорт того же `preset=1` находит существующую запись вместо
/// создания дубликата.
Subscription? findSubscriptionByUrl(
  Iterable<Subscription> subscriptions,
  String url,
) {
  for (final s in subscriptions) {
    if (s.url == url) return s;
  }
  return null;
}

class _SubscriptionUserinfo {
  final TrafficInfo traffic;
  final DateTime? expiresAt;
  const _SubscriptionUserinfo(this.traffic, this.expiresAt);
}

/// Де-факто стандартный заголовок панелей подписок (3x-ui, Marzban и т.п.):
/// `Subscription-Userinfo: upload=123; download=456; total=789; expire=169...`
/// `expire` — unix-время в секундах (0 или отсутствует — без срока).
_SubscriptionUserinfo? _parseSubscriptionUserinfo(
  Map<String, String> headers,
) {
  final header = headers['subscription-userinfo'];
  if (header == null) return null;

  final fields = <String, int>{};
  for (final part in header.split(';')) {
    final kv = part.trim().split('=');
    if (kv.length != 2) continue;
    final value = int.tryParse(kv[1].trim());
    if (value != null) fields[kv[0].trim().toLowerCase()] = value;
  }

  final upload = fields['upload'] ?? 0;
  final download = fields['download'] ?? 0;
  final total = fields['total'];
  if (total == null) return null;

  final expire = fields['expire'];
  final expiresAt = (expire == null || expire == 0)
      ? null
      : DateTime.fromMillisecondsSinceEpoch(expire * 1000);

  return _SubscriptionUserinfo(
    TrafficInfo(usedBytes: upload + download, totalBytes: total),
    expiresAt,
  );
}

/// Человекочитаемая аннотация подписки, обычно `base64:<...>` с
/// UTF‑8-текстом внутри (эмодзи, статус аккаунта и т.п.).
String? _parseAnnounce(Map<String, String> headers) {
  final header = headers['announce'];
  if (header == null || header.isEmpty) return null;

  final encoded = header.startsWith('base64:')
      ? header.substring('base64:'.length)
      : header;
  try {
    return utf8.decode(base64.decode(base64.normalize(encoded)));
  } catch (_) {
    return header;
  }
}

/// Произвольные кастомные поля от сервиса подписки (например
/// `{"Тариф": "Premium"}`), не описанные заранее в модели — см.
/// ROADMAP.md, трек 14. В отличие от `Subscription-Userinfo`/`Announce`
/// (числа/одна строка), значений тут может быть много и они могут быть
/// произвольным UTF-8 текстом, так что формат `key=value; key=value` из
/// `Subscription-Userinfo` не подходит — вместо этого целый JSON-объект,
/// закодированный тем же способом, что и `Announce` (`base64:<...>`).
Map<String, String> _parseCustomFields(Map<String, String> headers) {
  final header = headers['profile-custom-fields'];
  if (header == null || header.isEmpty) return const {};

  final encoded = header.startsWith('base64:')
      ? header.substring('base64:'.length)
      : header;
  try {
    final decoded = jsonDecode(utf8.decode(base64.decode(base64.normalize(encoded))));
    if (decoded is! Map) return const {};
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  } catch (_) {
    return const {};
  }
}

Map<String, dynamic>? _tryDecodeJsonObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
