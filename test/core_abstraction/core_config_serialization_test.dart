import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core_abstraction/core_config.dart';
import 'package:vpn_client/core_abstraction/proxy_node.dart';
import 'package:vpn_client/core_abstraction/server_config.dart';
import 'package:vpn_client/core_abstraction/subscription.dart';

void main() {
  test('CoreConfig round-trips through JSON', () {
    final config = CoreConfig(
      standaloneNodes: [
        ServerGroup(
          id: 'group-1',
          name: 'Basic',
          children: [
            const ServerLeaf(
              id: 'leaf-1',
              name: 'Germany #1',
              icon: '🇩🇪',
              variants: [
                ConnectionVariant(
                  id: 'variant-1',
                  label: 'TCP Reality',
                  config: VlessConfig(
                    address: 'de1.example.com',
                    port: 443,
                    uuid: 'uuid-1',
                    flow: 'xtls-rprx-vision',
                    network: VlessNetwork.tcp,
                    security: VlessSecurity.reality,
                    sni: 'example.com',
                    publicKey: 'pbk',
                    shortId: 'sid',
                    fingerprint: 'chrome',
                  ),
                ),
              ],
              selection: ManualVariantSelection('variant-1'),
            ),
          ],
          strategy: GroupStrategy.urlTest,
        ),
      ],
      subscriptions: [
        Subscription(
          id: 'sub-1',
          name: 'My subscription',
          url: 'https://example.com/sub',
          traffic: const TrafficInfo(usedBytes: 100, totalBytes: 1000),
          expiresAt: DateTime.utc(2027, 1, 1),
          root: const ServerLeaf(
            id: 'sub-leaf-1',
            name: 'Poland',
            variants: [
              ConnectionVariant(
                id: 'sub-variant-1',
                label: 'default',
                config: VlessConfig(
                  address: 'pl1.example.com',
                  port: 443,
                  uuid: 'uuid-2',
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final restored = CoreConfig.fromJson(config.toJson());

    expect(restored.schemaVersion, config.schemaVersion);
    expect(restored.standaloneNodes, hasLength(1));

    final group = restored.standaloneNodes.single as ServerGroup;
    expect(group.id, 'group-1');
    expect(group.strategy, GroupStrategy.urlTest);
    expect(group.children, hasLength(1));

    final leaf = group.children.single as ServerLeaf;
    expect(leaf.icon, '🇩🇪');
    expect(leaf.selection, isA<ManualVariantSelection>());
    expect((leaf.selection as ManualVariantSelection).variantId, 'variant-1');

    final vless = leaf.variants.single.config as VlessConfig;
    expect(vless.address, 'de1.example.com');
    expect(vless.security, VlessSecurity.reality);
    expect(vless.publicKey, 'pbk');

    expect(restored.subscriptions, hasLength(1));
    final sub = restored.subscriptions.single;
    expect(sub.name, 'My subscription');
    expect(sub.traffic?.usedBytes, 100);
    expect(sub.expiresAt, DateTime.utc(2027, 1, 1));
    expect(sub.root, isA<ServerLeaf>());
  });

  test('rejects unknown schemaVersion', () {
    expect(
      () => CoreConfig.fromJson({'schemaVersion': 999}),
      throwsFormatException,
    );
  });
}
