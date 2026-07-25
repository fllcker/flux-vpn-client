import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/mj_payload.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/core_abstraction/subscription.dart';

void main() {
  test('parses a subscriptions payload', () {
    final json = {
      'schemaVersion': 1,
      'type': 'subscriptions',
      'content': [
        Subscription(
          id: 'sub-1',
          name: 'Premium',
          url: 'https://example.com/mj',
          root: const ServerLeaf(
            id: 'leaf-1',
            name: 'Germany 1',
            variants: [
              ConnectionVariant(
                id: 'variant-1',
                label: 'default',
                config: Hysteria2Config(
                  address: 'de1.example.com',
                  port: 443,
                  auth: 'secret',
                ),
              ),
            ],
          ),
        ).toJson(),
      ],
    };

    final payload = MjPayload.fromJson(json);

    expect(payload, isA<MjSubscriptionsPayload>());
    final subscriptions = (payload as MjSubscriptionsPayload).subscriptions;
    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.id, 'sub-1');
    expect(subscriptions.single.root, isA<ServerLeaf>());
  });

  test('parses a nodes payload', () {
    final json = {
      'schemaVersion': 1,
      'type': 'nodes',
      'content': [
        const ServerGroup(
          id: 'group-1',
          name: 'Basic',
          children: [
            ServerLeaf(
              id: 'leaf-1',
              name: 'Finland 1',
              variants: [
                ConnectionVariant(
                  id: 'variant-1',
                  label: 'default',
                  config: Hysteria2Config(
                    address: 'fi1.example.com',
                    port: 443,
                    auth: 'secret',
                  ),
                ),
              ],
            ),
          ],
        ).toJson(),
      ],
    };

    final payload = MjPayload.fromJson(json);

    expect(payload, isA<MjNodesPayload>());
    final nodes = (payload as MjNodesPayload).nodes;
    expect(nodes, hasLength(1));
    expect(nodes.single, isA<ServerGroup>());
  });

  test('rejects unknown schemaVersion', () {
    expect(
      () => MjPayload.fromJson({
        'schemaVersion': 999,
        'type': 'nodes',
        'content': [],
      }),
      throwsFormatException,
    );
  });

  test('rejects unknown type', () {
    expect(
      () => MjPayload.fromJson({
        'schemaVersion': 1,
        'type': 'something-else',
        'content': [],
      }),
      throwsFormatException,
    );
  });

  test('looksLikePayload distinguishes MJ envelope from xray-json', () {
    expect(
      MjPayload.looksLikePayload({
        'schemaVersion': 1,
        'type': 'nodes',
        'content': [],
      }),
      isTrue,
    );
    expect(
      MjPayload.looksLikePayload({
        'remarks': 'Germany 1',
        'outbounds': [],
      }),
      isFalse,
    );
  });
}
