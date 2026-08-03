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
const _leaf2 = ServerLeaf(
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
const _leaf3 = ServerLeaf(
  id: 'leaf-3',
  name: 'C',
  variants: [
    ConnectionVariant(
      id: 'v3',
      label: 'TCP',
      config: VlessConfig(address: 'c.example.com', port: 443, uuid: 'u3'),
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

  test('AutoSelectMarker round-trips through JSON', () {
    const marker = AutoSelectMarker(id: 'auto-1');

    final restored = ProxyNode.fromJson(marker.toJson()) as AutoSelectMarker;

    expect(restored.id, 'auto-1');
    expect(restored.name, 'Авто');
  });

  test('setGroupStrategy replaces strategy on a matching group only', () {
    const nested = ServerGroup(id: 'nested', name: 'N', children: [_leaf]);
    const root = ServerGroup(id: 'root', name: 'R', children: [nested]);

    final result = setGroupStrategy(root, 'nested', GroupStrategy.urlTest) as ServerGroup;

    expect(result.strategy, GroupStrategy.select);
    expect((result.children.single as ServerGroup).strategy, GroupStrategy.urlTest);
  });

  test('setNodeHidden/replaceLeafSelection pass an AutoSelectMarker through unchanged', () {
    const marker = AutoSelectMarker(id: 'auto-1');
    const group = ServerGroup(id: 'g', name: 'G', children: [marker, _leaf]);

    final afterHidden = setNodeHidden(group, 'leaf-1', true) as ServerGroup;
    expect(afterHidden.children.first, same(marker));

    final afterSelection = replaceLeafSelection(group, 'leaf-1', 'v1') as ServerGroup;
    expect(afterSelection.children.first, same(marker));
  });

  test('moveNodeInTree reorders a leaf within the same group', () {
    const group = ServerGroup(
      id: 'g',
      name: 'G',
      children: [_leaf, _leaf2, _leaf3],
    );

    final result = moveNodeInTree(group, 'leaf-3', 'g', 0) as ServerGroup;

    expect(
      result.children.map((c) => c.id).toList(),
      ['leaf-3', 'leaf-1', 'leaf-2'],
    );
  });

  test('moveNodeInTree moves a leaf into a different nested group', () {
    const tree = ServerGroup(
      id: 'root',
      name: 'Root',
      children: [
        _leaf,
        ServerGroup(id: 'nested', name: 'Nested', children: [_leaf2]),
      ],
    );

    final result = moveNodeInTree(tree, 'leaf-1', 'nested', 1) as ServerGroup;

    expect(result.children.map((c) => c.id).toList(), ['nested']);
    final nested = result.children.single as ServerGroup;
    expect(nested.children.map((c) => c.id).toList(), ['leaf-2', 'leaf-1']);
  });

  test('moveNodeInTree is a no-op when the node id is not in this tree', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leaf]);

    final result = moveNodeInTree(group, 'not-found', 'g', 0);

    expect(result, same(group));
  });

  test('moveNodeInTree rolls back without losing the node when the target parent is not in this tree', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leaf, _leaf2]);

    final result = moveNodeInTree(group, 'leaf-1', 'other-tree-group', 0);

    expect(result, same(group));
  });

  test('moveNodeInTree never moves the AutoSelectMarker itself', () {
    const marker = AutoSelectMarker(id: 'auto-1');
    const group = ServerGroup(id: 'g', name: 'G', children: [marker, _leaf]);

    final result = moveNodeInTree(group, 'auto-1', 'g', 1);

    expect(result, same(group));
  });

  test('moveNodeInTree keeps the AutoSelectMarker first even when inserting at index 0', () {
    const marker = AutoSelectMarker(id: 'auto-1');
    const group = ServerGroup(
      id: 'g',
      name: 'G',
      children: [marker, _leaf, _leaf2],
    );

    final result = moveNodeInTree(group, 'leaf-2', 'g', 0) as ServerGroup;

    expect(
      result.children.map((c) => c.id).toList(),
      ['auto-1', 'leaf-2', 'leaf-1'],
    );
  });
}
