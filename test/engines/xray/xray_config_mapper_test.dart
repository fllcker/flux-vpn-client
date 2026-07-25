import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/app_settings.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/engines/xray/xray_config_mapper.dart';

const _server = VlessConfig(
  address: 'de1.example.com',
  port: 443,
  uuid: 'uuid-1',
);

void main() {
  // xray зовёт этот уровень `warning`, sing-box — `warn`. Общий enum настроек
  // обязан разъезжаться здесь, а не в конфиге: с чужим именем ядро не стартует.
  test('buildXrayConfig translates the shared log level to xray naming', () {
    Object? level(CoreLogLevel value) => (buildXrayConfig(
      _server,
      socksPort: 10808,
      httpPort: 10809,
      logLevel: value,
    )['log'] as Map)['loglevel'];

    expect(level(CoreLogLevel.warn), 'warning');
    expect(level(CoreLogLevel.debug), 'debug');
    expect(level(CoreLogLevel.error), 'error');
  });

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
}
