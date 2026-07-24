import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/reset_subscription_order.dart';

const _germany1 = ServerLeaf(
  id: 'de-1',
  name: 'Germany 1',
  hidden: true,
  variants: [
    ConnectionVariant(
      id: 'v1',
      label: 'TCP',
      config: VlessConfig(address: 'de1.example.com', port: 443, uuid: 'u1'),
    ),
  ],
);
const _germany2 = ServerLeaf(
  id: 'de-2',
  name: 'Germany 2',
  variants: [
    ConnectionVariant(
      id: 'v2',
      label: 'TCP',
      config: VlessConfig(address: 'de2.example.com', port: 443, uuid: 'u2'),
    ),
  ],
);
const _poland = ServerLeaf(
  id: 'pl-1',
  name: 'Poland 1',
  variants: [
    ConnectionVariant(
      id: 'v3',
      label: 'TCP',
      config: VlessConfig(address: 'pl1.example.com', port: 443, uuid: 'u3'),
    ),
  ],
);

void main() {
  test('rebuildDefaultOrder regroups by name and undoes manual drag order', () {
    // Пользователь перетащил Poland 1 первым и вынес Germany-серверы из
    // своей группы плоским списком — ручная сортировка ломает
    // автогруппировку по имени.
    const manuallyReordered = ServerGroup(
      id: 'root',
      name: 'Sub',
      children: [
        AutoSelectMarker(id: 'auto-root'),
        _poland,
        _germany1,
        _germany2,
      ],
    );

    final result = rebuildDefaultOrder(manuallyReordered);

    expect(result.id, 'root');
    expect(result.name, 'Sub');
    expect(result.children.first, isA<AutoSelectMarker>());

    final germanyGroup = result.children
        .whereType<ServerGroup>()
        .where((g) => g.name == 'Germany')
        .single;
    expect(germanyGroup.children.first, isA<AutoSelectMarker>());
    expect(
      germanyGroup.children.whereType<ServerLeaf>().map((l) => l.id),
      containsAll(['de-1', 'de-2']),
    );

    // hidden/id сохраняются — переставляется только положение в дереве.
    final restoredGermany1 = germanyGroup.children
        .whereType<ServerLeaf>()
        .firstWhere((l) => l.id == 'de-1');
    expect(restoredGermany1.hidden, isTrue);
  });
}
