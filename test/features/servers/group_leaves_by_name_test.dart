import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/group_leaves_by_name.dart';

ServerLeaf _leaf(String name, {List<RoutingRule> routingRules = const []}) =>
    ServerLeaf(
      id: name,
      name: name,
      variants: [
        ConnectionVariant(
          id: '$name-v',
          label: 'default',
          config: VlessConfig(address: '$name.example.com', port: 443, uuid: 'u'),
        ),
      ],
      routingRules: routingRules,
    );

void main() {
  test('groups a shared first segment, leaves a singleton flat', () {
    final leaves = [
      _leaf('Basic - Germany 1'),
      _leaf('Basic - Finland 1'),
      _leaf('Premium - Sweden 1'),
    ];

    final nodes = groupLeavesByName(leaves);

    // Только "Basic" стал группой — у "Premium" всего один элемент.
    expect(nodes.whereType<ServerGroup>().map((g) => g.name), ['Basic']);
    expect(nodes.whereType<ServerLeaf>().map((l) => l.name), [
      'Premium Sweden 1',
    ]);

    final basic = nodes.whereType<ServerGroup>().single;
    expect(basic.children.whereType<ServerLeaf>().map((l) => l.name), [
      'Germany 1',
      'Finland 1',
    ]);
  });

  test('collapses a non-branching chain into a single group', () {
    // "For"/"Anitype"/"for"/"AniType" никогда не расходятся между двумя
    // серверами — это не 4 вложенных группы, а одна ("AniType", по
    // последней общей части), внутри которой числовые остатки дублируют
    // имя группы.
    final leaves = [
      _leaf('For Anitype - for AniType 1'),
      _leaf('For Anitype - for AniType 2'),
    ];

    final nodes = groupLeavesByName(leaves);

    expect(nodes, hasLength(1));
    final group = nodes.single as ServerGroup;
    expect(group.name, 'AniType');
    expect(group.children.whereType<ServerLeaf>().map((l) => l.name), [
      'AniType 1',
      'AniType 2',
    ]);
  });

  test('nests a second shared segment, duplicating its name onto bare numbers', () {
    final leaves = [
      _leaf('Basic - Germany 1'),
      _leaf('Basic - Germany 2'),
      _leaf('Premium - Sweden 1'),
    ];

    final nodes = groupLeavesByName(leaves);

    final basic = nodes.whereType<ServerGroup>().firstWhere((g) => g.name == 'Basic');
    expect(basic.children, hasLength(1));

    final germany = basic.children.single as ServerGroup;
    expect(germany.name, 'Germany');
    expect(germany.children.whereType<ServerLeaf>().map((l) => l.name), [
      'Germany 1',
      'Germany 2',
    ]);
  });

  test('preserves routingRules on leaves rebuilt during grouping', () {
    // Регрессия: _toLeaf пересобирал ServerLeaf с новым именем, но забывал
    // передать routingRules — xray-json подписки с одинаковыми правилами
    // роутинга на каждом сервере теряли их сразу после группировки по
    // имени, хотя парсер их находил (см. ROADMAP.md).
    const rules = [
      DomainRule(values: ['geosite:category-ru'], outboundTag: 'direct'),
    ];
    final leaves = [
      _leaf('Basic - Germany 1', routingRules: rules),
      _leaf('Basic - Finland 1', routingRules: rules),
    ];

    final nodes = groupLeavesByName(leaves);

    final basic = nodes.whereType<ServerGroup>().single;
    for (final leaf in basic.children.whereType<ServerLeaf>()) {
      expect(leaf.routingRules, rules);
    }
  });

  test('leaves an ungroupable flat list untouched', () {
    final leaves = [_leaf('Netherlands'), _leaf('Poland'), _leaf('Japan')];

    final nodes = groupLeavesByName(leaves);

    expect(nodes.whereType<ServerLeaf>().map((l) => l.name), [
      'Netherlands',
      'Poland',
      'Japan',
    ]);
  });
}
