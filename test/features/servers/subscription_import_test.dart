import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/core_abstraction/subscription.dart';
import 'package:flux/features/servers/subscription_import.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _variant = ConnectionVariant(
  id: 'v1',
  label: 'TCP Reality',
  config: VlessConfig(address: 'de1.example.com', port: 443, uuid: 'u1'),
);
const _leaf = ServerLeaf(
  id: 'leaf1',
  name: 'Germany 1',
  variants: [_variant],
  selection: ManualVariantSelection('v1'),
);

Subscription _baseSubscription({
  required String url,
  List<String> fallbackDomains = const [],
  String? fallbackDomainsUrl,
  int domainTimeoutMs = 200,
}) => Subscription(
  id: 'sub1',
  name: 'Sub',
  url: url,
  fallbackDomains: fallbackDomains,
  fallbackDomainsUrl: fallbackDomainsUrl,
  domainTimeoutMs: domainTimeoutMs,
  root: const ServerGroup(id: 'root', name: 'Sub', children: [_leaf]),
);

String _mjBody(Subscription subscription) => jsonEncode({
  'schemaVersion': 1,
  'type': 'subscriptions',
  'content': [subscription.toJson()],
});

void main() {
  group('importLink domain-unavailable classification', () {
    test('SocketException becomes DomainUnavailableFailure', () async {
      final client = MockClient((request) async {
        throw const SocketException('connection refused');
      });

      final result = await importLink(
        'https://example.com/sub',
        client: client,
      );

      expect(result, isA<DomainUnavailableFailure>());
    });

    test('a slow response past the timeout becomes DomainUnavailableFailure', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      });

      final result = await importLink(
        'https://example.com/sub',
        client: client,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isA<DomainUnavailableFailure>());
    });

    test('a real 5xx from a live server is a plain LinkImportFailure, not domain-unavailable', () async {
      final client = MockClient((request) async => http.Response('error', 503));

      final result = await importLink(
        'https://example.com/sub',
        client: client,
      );

      expect(result, isA<LinkImportFailure>());
      expect(result, isNot(isA<DomainUnavailableFailure>()));
    });
  });

  group('refreshSubscription fallback domains (ROADMAP.md, трек 23)', () {
    test('falls back to the next static domain when the primary domain is unavailable', () async {
      final replacement = _baseSubscription(url: 'https://example.com/sub/id1');
      final client = MockClient((request) async {
        if (request.url.host == 'example.com') {
          throw const SocketException('name not resolved');
        }
        if (request.url.host == 'example2.com') {
          return http.Response(_mjBody(replacement), 200);
        }
        throw StateError('unexpected host ${request.url.host}');
      });

      final subscription = _baseSubscription(
        url: 'https://example.com/sub/id1',
        fallbackDomains: const ['example2.com'],
      );

      final result = await refreshSubscription(subscription, client: client);

      expect(result, isA<SubscriptionImportResultOk>());
      final merged = (result as SubscriptionImportResultOk).subscription;
      // Путь/query сохранены, поменялся только хост.
      expect(merged.url, 'https://example2.com/sub/id1');
    });

    test('fetches the fallback domains URL once the static list is exhausted, and replaces it', () async {
      final replacement = _baseSubscription(url: 'https://example.com/sub/id1');
      final client = MockClient((request) async {
        if (request.url.host == 'example.com' && request.url.path == '/sub/id1') {
          throw const SocketException('name not resolved');
        }
        if (request.url.host == 'dead-fallback.example') {
          throw const SocketException('name not resolved');
        }
        if (request.url.toString() == 'https://raw.example/domains.json') {
          return http.Response(
            jsonEncode({'domains': ['example3.com']}),
            200,
          );
        }
        if (request.url.host == 'example3.com') {
          return http.Response(_mjBody(replacement), 200);
        }
        throw StateError('unexpected request ${request.url}');
      });

      final subscription = _baseSubscription(
        url: 'https://example.com/sub/id1',
        fallbackDomains: const ['dead-fallback.example'],
        fallbackDomainsUrl: 'https://raw.example/domains.json',
      );

      final result = await refreshSubscription(subscription, client: client);

      expect(result, isA<SubscriptionImportResultOk>());
      final merged = (result as SubscriptionImportResultOk).subscription;
      expect(merged.url, 'https://example3.com/sub/id1');
      // Статический список заменён результатом JSON-фетча этого раунда.
      expect(merged.fallbackDomains, ['example3.com']);
    });

    test('does not attempt any fallback when the primary domain returns a real HTTP error', () async {
      var fallbackHostRequested = false;
      final client = MockClient((request) async {
        if (request.url.host == 'example.com') {
          return http.Response('server error', 500);
        }
        fallbackHostRequested = true;
        throw StateError('should not be called');
      });

      final subscription = _baseSubscription(
        url: 'https://example.com/sub/id1',
        fallbackDomains: const ['example2.com'],
      );

      final result = await refreshSubscription(subscription, client: client);

      expect(fallbackHostRequested, isFalse);
      expect(result, isA<LinkImportFailure>());
      expect(result, isNot(isA<DomainUnavailableFailure>()));
    });

    test('with no fallback domains configured, a domain-unavailable failure is returned as-is', () async {
      final client = MockClient((request) async {
        throw const SocketException('name not resolved');
      });

      final subscription = _baseSubscription(url: 'https://example.com/sub/id1');

      final result = await refreshSubscription(subscription, client: client);

      expect(result, isA<DomainUnavailableFailure>());
    });
  });
}
