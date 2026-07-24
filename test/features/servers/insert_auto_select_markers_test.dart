import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/insert_auto_select_markers.dart';

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
  test('inserts an AutoSelectMarker as the first child of every group', () {
    const tree = ServerGroup(
      id: 'root',
      name: 'Root',
      children: [
        ServerGroup(id: 'nested', name: 'Nested', children: [_leaf]),
      ],
    );

    final result = insertAutoSelectMarkers(tree) as ServerGroup;

    expect(result.children.first, isA<AutoSelectMarker>());
    expect(result.children, hasLength(2));

    final nested = result.children[1] as ServerGroup;
    expect(nested.children.first, isA<AutoSelectMarker>());
    expect(nested.children, hasLength(2));
    expect(nested.children[1], isA<ServerLeaf>());
  });

  test('leaves a bare ServerLeaf untouched', () {
    expect(insertAutoSelectMarkers(_leaf), same(_leaf));
  });
}
