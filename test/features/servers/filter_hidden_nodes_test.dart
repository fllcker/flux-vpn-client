import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/filter_hidden_nodes.dart';

const _leafA = ServerLeaf(
  id: 'a',
  name: 'A',
  variants: [
    ConnectionVariant(
      id: 'a-v1',
      label: 'TCP',
      config: VlessConfig(address: 'a.example.com', port: 443, uuid: 'u'),
    ),
  ],
);
const _leafB = ServerLeaf(
  id: 'b',
  name: 'B',
  hidden: true,
  variants: [
    ConnectionVariant(
      id: 'b-v1',
      label: 'TCP',
      config: VlessConfig(address: 'b.example.com', port: 443, uuid: 'u'),
    ),
  ],
);

void main() {
  test('a visible leaf passes through unchanged', () {
    expect(filterHidden(_leafA), same(_leafA));
  });

  test('a hidden leaf is filtered out', () {
    expect(filterHidden(_leafB), isNull);
  });

  test('a group with only hidden children disappears entirely', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leafB]);

    expect(filterHidden(group), isNull);
  });

  test('a group with a mix of visible/hidden children keeps only the visible ones', () {
    const group = ServerGroup(id: 'g', name: 'G', children: [_leafA, _leafB]);

    final filtered = filterHidden(group) as ServerGroup;

    expect(filtered.children, hasLength(1));
    expect((filtered.children.single as ServerLeaf).id, 'a');
  });

  test('filterHiddenList drops hidden top-level nodes', () {
    final filtered = filterHiddenList([_leafA, _leafB]);

    expect(filtered, hasLength(1));
    expect((filtered.single as ServerLeaf).id, 'a');
  });
}
