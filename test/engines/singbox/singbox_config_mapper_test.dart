import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/app_settings.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/engines/singbox/singbox_config_mapper.dart';

Map<String, dynamic> buildConfig({
  int socksInPort = 10808,
  String serverHost = 'de1.example.com',
  List<String> serverIps = const ['203.0.113.7'],
  String upstreamDns = defaultTunDnsServer,
  CoreLogLevel logLevel = CoreLogLevel.warn,
  List<RoutingRule> routingRules = const [],
  Map<String, String> ruleSetPaths = const {},
}) => buildSingBoxTunBridgeConfig(
  socksInPort: socksInPort,
  serverHost: serverHost,
  serverIps: serverIps,
  upstreamDns: upstreamDns,
  logLevel: logLevel,
  routingRules: routingRules,
  ruleSetPaths: ruleSetPaths,
);

List<Map> routeRules(Map<String, dynamic> config) =>
    ((config['route'] as Map)['rules'] as List).cast<Map>();

// List's `==` is reference equality in Dart, not structural — this compares
// contents, since route rule values are always freshly-built lists.
bool _listEquals(Object? a, List<Object?> b) =>
    a is List && a.length == b.length && [for (var i = 0; i < b.length; i++) a[i] == b[i]].every((x) => x);

void main() {
  test('buildSingBoxTunBridgeConfig points the socks outbound at the given port', () {
    final config = buildConfig(socksInPort: 10808);

    final outbounds = (config['outbounds'] as List).cast<Map>();
    final outbound = outbounds.firstWhere((o) => o['type'] == 'socks');
    expect(outbound['server'], '127.0.0.1');
    expect(outbound['server_port'], 10808);

    final route = config['route'] as Map;
    expect(route['final'], outbound['tag']);
  });

  test('buildSingBoxTunBridgeConfig configures the tun inbound for auto routing', () {
    final config = buildConfig(socksInPort: 10809);

    final inbound = (config['inbounds'] as List).single as Map;
    expect(inbound['type'], 'tun');
    expect(inbound['interface_name'], tunInterfaceName);
    expect(inbound['auto_route'], isTrue);
    expect(inbound['address'], contains('172.19.0.1/30'));
    // IPv4-only address would leave Windows preferring a real IPv6 uplink
    // over the tunnel per RFC 6724 — see the doc comment in the mapper.
    expect(
      (inbound['address'] as List).any((a) => (a as String).contains(':')),
      isTrue,
    );

    final route = config['route'] as Map;
    expect(route['auto_detect_interface'], isTrue);
  });

  // Сниффинг обязан быть отдельным правилом, а не полем `sniff` на inbound:
  // sing-box 1.13 на legacy-поле падает при старте, ещё не подняв TUN.
  test('buildSingBoxTunBridgeConfig sniffs via a rule action, never on the inbound', () {
    final config = buildConfig();

    expect((config['inbounds'] as List).single as Map, isNot(contains('sniff')));
    expect(routeRules(config).any((r) => r['action'] == 'sniff'), isTrue);
  });

  // sing-box и xray называют уровни по-разному (`warn` против `warning`), и
  // перепутанное имя роняет ядро на старте, а не пишется молча в лог.
  test('buildSingBoxTunBridgeConfig uses sing-box log level names', () {
    expect(
      (buildConfig(logLevel: CoreLogLevel.debug)['log'] as Map)['level'],
      'debug',
    );
    expect(
      (buildConfig(logLevel: CoreLogLevel.warn)['log'] as Map)['level'],
      'warn',
    );
  });

  // Со своим DoH браузер резолвит мимо нашего хиджека — а значит мимо
  // ipv4_only и доменных правил роутинга. Плюс на части серверов его проба
  // подвисает, и навигация буксует, пока та не отвалится по таймауту.
  test('buildSingBoxTunBridgeConfig rejects browser DoH endpoints', () {
    final rules = routeRules(buildConfig());
    final doh = rules.firstWhere(
      (r) => r['action'] == 'reject' && r['port'] == 443,
    );

    final blocked = (doh['ip_cidr'] as List).cast<String>();
    expect(blocked, containsAll(['8.8.8.8/32', '1.1.1.1/32']));
    // Свой DoT мы шлём на тот же адрес, но по 853 — правило обязано смотреть на
    // порт, иначе оно отстрелит собственный резолвер.
    expect(doh['port'], isNot(853));
  });

  // Блокировка QUIC тут стояла и была снята: шторм UDP-ретраев оказался
  // симптомом медленного IPv6, а не поломки UDP-пути. Возврат правила лечил бы
  // симптом ценой HTTP/3, поэтому пусть его отсутствие будет зафиксировано.
  test('buildSingBoxTunBridgeConfig does not block QUIC', () {
    final rules = routeRules(buildConfig());

    expect(
      rules.any((r) => r['network'] == 'udp' && r['port'] == 443),
      isFalse,
    );
  });

  test('buildSingBoxTunBridgeConfig hijacks DNS by port, not by sniffed protocol', () {
    final rules = routeRules(buildConfig());
    final hijack = rules.firstWhere((r) => r['action'] == 'hijack-dns');

    // По `protocol: dns` сниффер тащит сюда ещё и LLMNR/mDNS/NetBIOS-NS, а те
    // не разбираются DNS-парсером и заваливают лог `bad question name`.
    expect(hijack['port'], 53);
    expect(hijack, isNot(contains('protocol')));

    // Мультикаст и бродкаст должны отсекаться раньше хиджека — иначе они до
    // него доходят по тому же порту.
    final rejectIndex = rules.indexWhere((r) => r['action'] == 'reject');
    expect(rejectIndex, isNonNegative);
    expect(rejectIndex, lessThan(rules.indexOf(hijack)));
    expect(rules[rejectIndex]['ip_cidr'], contains('224.0.0.0/4'));
  });

  group('bypass for xray\'s own traffic', () {
    test('resolves the server host through a DNS server that skips the tunnel', () {
      final config = buildConfig(serverHost: 'de1.example.com');

      final dns = config['dns'] as Map;
      final servers = (dns['servers'] as List).cast<Map>();
      final rule = (dns['rules'] as List).cast<Map>().single;

      expect(rule['domain'], ['de1.example.com']);
      final bootstrap = servers.firstWhere((s) => s['tag'] == rule['server']);
      // Уйди этот резолв в xray — получился бы замкнутый круг: xray'ю нужен
      // тоннель, чтобы отрезолвить адрес сервера, к которому он подключается.
      // Отсутствие `detour` и есть «напрямую»; написать `detour: direct` явно
      // нельзя — на таком sing-box 1.13 падает при старте.
      expect(bootstrap, isNot(contains('detour')));
      expect(bootstrap['type'], 'tls', reason: 'DNS мимо тоннеля — только DoT');
    });

    test('keeps traffic on IPv4 while still capturing IPv6', () {
      final config = buildConfig();

      // Замеры одного сеанса: медиана соединения к IPv6 — 1.24s против 0.01s у
      // IPv4, и по IPv6 при этом шло 179 соединений из 198.
      expect((config['dns'] as Map)['strategy'], 'ipv4_only');
      // Но сам IPv6 на TUN остаётся — иначе обращения к literal-IPv6 потекут
      // мимо тоннеля, а это уже утечка, а не медленная работа.
      final inbound = (config['inbounds'] as List).single as Map;
      expect(
        (inbound['address'] as List).any((a) => (a as String).contains(':')),
        isTrue,
      );
    });

    test('sends the configured upstream to both resolvers', () {
      final config = buildConfig(upstreamDns: '9.9.9.9');

      final servers = ((config['dns'] as Map)['servers'] as List).cast<Map>();
      // Оба — и тот, что внутри тоннеля, и bootstrap: разъехавшись, они дали бы
      // резолв, зависящий от того, поднялся тоннель или нет.
      expect(servers.map((s) => s['server']), everyElement('9.9.9.9'));
    });

    test('keeps DNS for everything else inside the tunnel', () {
      final config = buildConfig();

      final servers = ((config['dns'] as Map)['servers'] as List).cast<Map>();
      final remote = servers.firstWhere((s) => s['tag'] == 'remote');
      expect(remote['detour'], 'xray-socks-out');
    });

    test('keeps the server address out of the tunnel at the routing-table level', () {
      final config = buildConfig(serverIps: const ['203.0.113.7', '2001:db8::1']);

      // Хайрпин «в TUN и сразу обратно наружу» формально работает, но гонит весь
      // трафик тоннеля через userspace-стек дважды — страницы грузились по 30-40
      // секунд. Пакеты xray к серверу не должны попадать в TUN вообще.
      final inbound = (config['inbounds'] as List).single as Map;
      expect(
        inbound['route_exclude_address'],
        containsAll(['203.0.113.7/32', '2001:db8::1/128']),
      );
    });

    test('routes the pinned server IPs direct as a fallback', () {
      final config = buildConfig(serverIps: const ['203.0.113.7', '2001:db8::1']);

      final direct = routeRules(config).where((r) => r['outbound'] == 'direct');
      // Голый адрес без префикса sing-box в `ip_cidr` не принимает.
      expect(
        direct.expand((r) => (r['ip_cidr'] as List? ?? const [])),
        containsAll(['203.0.113.7/32', '2001:db8::1/128']),
      );
    });

    // Сопоставление по имени процесса заставляло sing-box на каждое соединение
    // перечислять таблицу TCP, дублируя обход, который и так сделан дважды.
    test('never matches on process name', () {
      final rules = routeRules(buildConfig());

      expect(rules.any((r) => r.containsKey('process_name')), isFalse);
    });

    test('omits both bypasses when the host could not be pre-resolved', () {
      final config = buildConfig(serverIps: const []);

      final inbound = (config['inbounds'] as List).single as Map;
      expect(inbound, isNot(contains('route_exclude_address')));
      // Мультикаст-reject тоже ходит по ip_cidr, поэтому смотрим именно на
      // правила, разворачивающие трафик наружу.
      final direct = routeRules(config).where((r) => r['outbound'] == 'direct');
      expect(direct, isEmpty);
      // Резолв домена сервера мимо тоннеля при этом остаётся — он единственный,
      // что разрывает замкнутый круг, и от пре-резолва не зависит.
      final dnsRule = ((config['dns'] as Map)['rules'] as List).single as Map;
      expect(dnsRule['server'], 'bootstrap');
    });

    test('declares a domain resolver that does not depend on the tunnel', () {
      final config = buildConfig();

      // Без этого ключа sing-box 1.12+ вообще не стартует.
      final resolver = (config['route'] as Map)['default_domain_resolver'];
      final servers = ((config['dns'] as Map)['servers'] as List).cast<Map>();
      final server = servers.firstWhere((s) => s['tag'] == resolver);
      expect(server, isNot(contains('detour')));
    });
  });

  group('user routing rules (ServerLeaf.routingRules, трек 21)', () {
    test('come after all infrastructure rules', () {
      final config = buildConfig(
        routingRules: const [
          DomainRule(values: ['example.com'], outboundTag: 'direct'),
        ],
      );

      final rules = routeRules(config);
      // Последнее инфраструктурное правило — обход IP сервера (direct по
      // ip_cidr). Пользовательское правило должно идти строго после него.
      final serverBypassIndex = rules.indexWhere(
        (r) => r['outbound'] == 'direct' && r.containsKey('ip_cidr'),
      );
      final userRuleIndex = rules.indexWhere(
        (r) => r['domain_keyword'] != null,
      );
      expect(serverBypassIndex, greaterThanOrEqualTo(0));
      expect(userRuleIndex, greaterThan(serverBypassIndex));
    });

    test('maps plain domain values by xray-style prefix', () {
      final config = buildConfig(
        routingRules: const [
          DomainRule(
            values: ['bare.example', 'domain:sub.example.com', 'full:exact.example.com', 'regexp:^ad'],
            outboundTag: 'direct',
          ),
        ],
      );

      final rule = routeRules(
        config,
      ).firstWhere((r) => r['outbound'] == 'direct' && r.containsKey('domain_keyword'));
      expect(rule['domain_keyword'], ['bare.example']);
      expect(rule['domain_suffix'], ['sub.example.com']);
      expect(rule['domain'], ['exact.example.com']);
      expect(rule['domain_regex'], ['^ad']);
    });

    test('maps "direct"/"block" tags to outbound/action, skips "proxy"', () {
      final config = buildConfig(
        routingRules: const [
          DomainRule(values: ['direct.example'], outboundTag: 'direct'),
          DomainRule(values: ['blocked.example'], outboundTag: 'block'),
          DomainRule(values: ['proxied.example'], outboundTag: 'proxy'),
        ],
      );

      final rules = routeRules(config);
      final direct = rules.firstWhere((r) => _listEquals(r['domain_keyword'], ['direct.example']));
      expect(direct['outbound'], 'direct');
      expect(direct.containsKey('action'), isFalse);

      final blocked = rules.firstWhere((r) => _listEquals(r['domain_keyword'], ['blocked.example']));
      expect(blocked['action'], 'reject');
      expect(blocked.containsKey('outbound'), isFalse);

      expect(rules.any((r) => _listEquals(r['domain_keyword'], ['proxied.example'])), isFalse);
    });

    test('IpRule maps ip_cidr values and skips "proxy"', () {
      final config = buildConfig(
        routingRules: const [
          IpRule(values: ['1.2.3.0/24'], outboundTag: 'direct'),
          IpRule(values: ['4.5.6.0/24'], outboundTag: 'proxy'),
        ],
      );

      final rules = routeRules(config);
      expect(
        rules.any((r) => _listEquals(r['ip_cidr'], ['1.2.3.0/24']) && r['outbound'] == 'direct'),
        isTrue,
      );
      expect(rules.any((r) => _listEquals(r['ip_cidr'], ['4.5.6.0/24'])), isFalse);
    });

    test('geosite:/geoip: values become rule_set references, not domain/ip_cidr', () {
      final config = buildConfig(
        routingRules: const [
          DomainRule(values: ['geosite:category-ads'], outboundTag: 'block'),
          IpRule(values: ['geoip:cn'], outboundTag: 'direct'),
        ],
        ruleSetPaths: const {
          'geosite-category-ads': 'C:/geo/geosite-category-ads.json',
          'geoip-cn': 'C:/geo/geoip-cn.json',
        },
      );

      final rules = routeRules(config);
      final domainRule = rules.firstWhere(
        (r) => _listEquals(r['rule_set'], ['geosite-category-ads']),
      );
      expect(domainRule['action'], 'reject');
      expect(domainRule.containsKey('domain'), isFalse);
      expect(domainRule.containsKey('domain_keyword'), isFalse);

      final ipRule = rules.firstWhere((r) => _listEquals(r['rule_set'], ['geoip-cn']));
      expect(ipRule['outbound'], 'direct');
      expect(ipRule.containsKey('ip_cidr'), isFalse);

      final ruleSets = (config['route'] as Map)['rule_set'] as List;
      expect(ruleSets, hasLength(2));
      final ruleSetsByTag = {
        for (final rs in ruleSets.cast<Map>()) rs['tag'] as String: rs,
      };
      expect(ruleSetsByTag['geosite-category-ads']!['path'], 'C:/geo/geosite-category-ads.json');
      expect(ruleSetsByTag['geosite-category-ads']!['format'], 'source');
      expect(ruleSetsByTag['geoip-cn']!['path'], 'C:/geo/geoip-cn.json');
    });

    test('geoRuleSetReferences collects unique tags across rules', () {
      final tags = geoRuleSetReferences(const [
        DomainRule(values: ['geosite:ads', 'geosite:ads', 'plain.example'], outboundTag: 'direct'),
        IpRule(values: ['geoip:cn'], outboundTag: 'block'),
      ]);
      expect(tags, {'geosite-ads', 'geoip-cn'});
    });

    test('omits route.rule_set entirely when no geosite/geoip references exist', () {
      final config = buildConfig(
        routingRules: const [
          DomainRule(values: ['plain.example'], outboundTag: 'direct'),
        ],
      );
      expect((config['route'] as Map).containsKey('rule_set'), isFalse);
    });
  });
}
