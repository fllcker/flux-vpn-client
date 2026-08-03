import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/routing_preset.dart';
import 'package:flux/features/servers/routing_preset_exchange.dart';

void main() {
  const preset = RoutingPreset(
    id: 'local-id',
    name: 'Gaming mode',
    rules: [
      DomainRule(values: ['geosite:telegram'], outboundTag: 'proxy'),
      IpRule(values: ['1.2.3.0/24'], outboundTag: 'block'),
    ],
    defaultOutboundTag: 'direct',
  );

  group('exportRoutingPresetJson', () {
    test('omits local-only fields (id/source/subscriptionId/sourceUrl)', () {
      final json = exportRoutingPresetJson(preset);

      expect(json.keys, containsAll(['name', 'rules', 'defaultOutboundTag']));
      expect(json.keys, isNot(contains('id')));
      expect(json.keys, isNot(contains('source')));
      expect(json['name'], 'Gaming mode');
      expect(json['defaultOutboundTag'], 'direct');
      expect(json['rules'], hasLength(2));
    });
  });

  group('parseRoutingPresetBlueprints', () {
    test('round-trips a single exported preset object', () {
      final json = exportRoutingPresetJson(preset);
      final blueprints = parseRoutingPresetBlueprints(json);

      expect(blueprints, hasLength(1));
      expect(blueprints.single.name, 'Gaming mode');
      expect(blueprints.single.defaultOutboundTag, 'direct');
      expect(blueprints.single.rules, hasLength(2));
    });

    test('accepts a bare JSON array of presets', () {
      final json = [
        exportRoutingPresetJson(preset),
        exportRoutingPresetJson(preset.copyWith(name: 'Second')),
      ];
      final blueprints = parseRoutingPresetBlueprints(json);

      expect(blueprints, hasLength(2));
      expect(blueprints[0].name, 'Gaming mode');
      expect(blueprints[1].name, 'Second');
    });

    test('accepts a {"presets": [...]} wrapper', () {
      final json = {
        'presets': [exportRoutingPresetJson(preset)],
      };
      final blueprints = parseRoutingPresetBlueprints(json);

      expect(blueprints, hasLength(1));
      expect(blueprints.single.name, 'Gaming mode');
    });

    test('defaults defaultOutboundTag to proxy when absent', () {
      final blueprints = parseRoutingPresetBlueprints({
        'name': 'No tag',
        'rules': [],
      });

      expect(blueprints.single.defaultOutboundTag, 'proxy');
    });

    test('rejects a preset object with no name', () {
      expect(
        () => parseRoutingPresetBlueprints({'rules': []}),
        throwsFormatException,
      );
    });

    test('rejects an empty preset list', () {
      expect(() => parseRoutingPresetBlueprints([]), throwsFormatException);
    });

    test('rejects an unrecognized top-level shape', () {
      expect(() => parseRoutingPresetBlueprints(42), throwsFormatException);
    });
  });
}
