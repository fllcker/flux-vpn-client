import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/effective_routing.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/routing_preset.dart';
import 'package:flux/core_abstraction/server_config.dart';

const _leafRules = [
  DomainRule(values: ['leaf.example.com'], outboundTag: 'direct'),
];

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
  routingRules: _leafRules,
);

const _presetRules = [
  DomainRule(values: ['preset.example.com'], outboundTag: 'block'),
];

const _preset = RoutingPreset(
  id: 'preset-1',
  name: 'Custom',
  rules: _presetRules,
);

void main() {
  test('null activePresetId falls back to the leaf\'s own routingRules', () {
    final rules = effectiveRoutingRules(
      leaf: _leaf,
      activePresetId: null,
      presets: [_preset],
    );
    expect(rules, same(_leafRules));
  });

  test('a valid activePresetId returns that preset\'s rules', () {
    final rules = effectiveRoutingRules(
      leaf: _leaf,
      activePresetId: 'preset-1',
      presets: [_preset],
    );
    expect(rules, same(_presetRules));
  });

  test('a dangling activePresetId (preset deleted) falls back to leaf rules', () {
    final rules = effectiveRoutingRules(
      leaf: _leaf,
      activePresetId: 'no-such-preset',
      presets: [_preset],
    );
    expect(rules, same(_leafRules));
  });
}
