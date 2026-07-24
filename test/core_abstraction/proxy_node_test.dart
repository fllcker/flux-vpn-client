import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';

const _leaf = ServerLeaf(
  id: 'leaf-1',
  name: 'A',
  variants: [
    ConnectionVariant(
      id: 'v1',
      label: 'TCP',
      config: VlessConfig(address: 'a.example.com', port: 443, uuid: 'u'),
    ),
  ],
);

void main() {
  test('setNodeHidden flips hidden on a matching leaf, leaves others untouched', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leaf]);

    final hidden = setNodeHidden(group, 'leaf-1', true) as ServerGroup;
    expect((hidden.children.single as ServerLeaf).hidden, isTrue);

    final shown = setNodeHidden(hidden, 'leaf-1', false) as ServerGroup;
    expect((shown.children.single as ServerLeaf).hidden, isFalse);
  });

  test('setNodeHidden on an unrelated id is a no-op', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leaf]);

    final result = setNodeHidden(group, 'not-found', true) as ServerGroup;

    expect((result.children.single as ServerLeaf).hidden, isFalse);
  });

  test('setLeafRoutingRules replaces rules on a matching leaf only', () {
    const other = ServerLeaf(
      id: 'leaf-2',
      name: 'B',
      variants: [
        ConnectionVariant(
          id: 'v2',
          label: 'TCP',
          config: VlessConfig(address: 'b.example.com', port: 443, uuid: 'u2'),
        ),
      ],
    );
    const group = ServerGroup(id: 'g', name: 'G', children: [_leaf, other]);
    const rules = [
      DomainRule(values: ['geosite:category-ads'], outboundTag: 'block'),
    ];

    final result = setLeafRoutingRules(group, 'leaf-1', rules) as ServerGroup;

    expect((result.children[0] as ServerLeaf).routingRules, rules);
    expect((result.children[1] as ServerLeaf).routingRules, isEmpty);
  });

  test('RoutingRule round-trips through JSON', () {
    const domain = DomainRule(
      values: ['example.com', 'geosite:category-ads'],
      outboundTag: 'block',
    );
    const ip = IpRule(values: ['1.2.3.0/24', 'geoip:cn'], outboundTag: 'direct');

    final restoredDomain = RoutingRule.fromJson(domain.toJson()) as DomainRule;
    final restoredIp = RoutingRule.fromJson(ip.toJson()) as IpRule;

    expect(restoredDomain.values, domain.values);
    expect(restoredDomain.outboundTag, 'block');
    expect(restoredIp.values, ip.values);
    expect(restoredIp.outboundTag, 'direct');
  });
}
