import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core_abstraction/proxy_node.dart';
import 'package:vpn_client/core_abstraction/server_config.dart';
import 'package:vpn_client/features/servers/import_result.dart';
import 'package:vpn_client/features/servers/import_to_proxy_nodes.dart';

void main() {
  test('converts imported servers to one ServerLeaf each', () {
    final servers = [
      const ImportedServer(
        name: 'Germany #1',
        config: VlessConfig(address: 'de1.example.com', port: 443, uuid: 'u1'),
      ),
      const ImportedServer(
        name: 'Poland',
        config: VlessConfig(address: 'pl1.example.com', port: 443, uuid: 'u2'),
      ),
      const ImportedServer(
        name: 'DE Basic - Germany 2',
        config: VlessConfig(address: 'de2.example.com', port: 443, uuid: 'u3'),
      ),
    ];

    final leaves = importedServersToLeaves(servers);

    expect(leaves, hasLength(3));
    expect(leaves[0].name, 'Germany #1');
    expect(leaves[0].icon, isNull);
    expect(leaves[2].name, 'Basic - Germany 2');
    expect(leaves[2].icon, '🇩🇪');
    expect(leaves[0].variants, hasLength(1));
    expect(leaves[0].selection, isA<ManualVariantSelection>());
    expect(
      (leaves[0].selection as ManualVariantSelection).variantId,
      leaves[0].variants.single.id,
    );
    // id-ы не должны совпадать между разными серверами
    expect(leaves[0].id, isNot(leaves[1].id));
  });
}
