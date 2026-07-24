import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/engines/xray/xray_config_mapper.dart';

const _server = VlessConfig(
  address: 'de1.example.com',
  port: 443,
  uuid: 'uuid-1',
);

void main() {
  test('buildXrayConfig omits routing section when no rules are set', () {
    final config = buildXrayConfig(_server, socksPort: 10808, httpPort: 10809);
    expect(config.containsKey('routing'), isFalse);
  });

  test('buildXrayConfig maps DomainRule/IpRule to xray field rules', () {
    final config = buildXrayConfig(
      _server,
      socksPort: 10808,
      httpPort: 10809,
      routingRules: const [
        DomainRule(values: ['geosite:category-ads'], outboundTag: 'block'),
        IpRule(values: ['1.2.3.0/24'], outboundTag: 'direct'),
      ],
    );

    final rules = (config['routing'] as Map)['rules'] as List;
    expect(rules, hasLength(2));
    expect(rules[0], {
      'type': 'field',
      'domain': ['geosite:category-ads'],
      'outboundTag': 'block',
    });
    expect(rules[1], {
      'type': 'field',
      'ip': ['1.2.3.0/24'],
      'outboundTag': 'direct',
    });

    final outboundTags = (config['outbounds'] as List)
        .map((o) => (o as Map)['tag'])
        .toList();
    expect(outboundTags, containsAll(['proxy', 'direct', 'block']));
  });

  test('buildXrayTunConfig maps routing rules the same way', () {
    final config = buildXrayTunConfig(
      _server,
      routingRules: const [
        DomainRule(values: ['example.com'], outboundTag: 'proxy'),
      ],
    );

    final rules = (config['routing'] as Map)['rules'] as List;
    expect(rules.single, {
      'type': 'field',
      'domain': ['example.com'],
      'outboundTag': 'proxy',
    });
  });
}
