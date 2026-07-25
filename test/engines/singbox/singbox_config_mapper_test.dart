import 'package:flutter_test/flutter_test.dart';
import 'package:flux/engines/singbox/singbox_config_mapper.dart';

void main() {
  test('buildSingBoxTunBridgeConfig points the socks outbound at the given port', () {
    final config = buildSingBoxTunBridgeConfig(socksInPort: 10808);

    final outbound = (config['outbounds'] as List).single as Map;
    expect(outbound['type'], 'socks');
    expect(outbound['server'], '127.0.0.1');
    expect(outbound['server_port'], 10808);

    final route = config['route'] as Map;
    expect(route['final'], outbound['tag']);
  });

  test('buildSingBoxTunBridgeConfig configures the tun inbound for auto routing', () {
    final config = buildSingBoxTunBridgeConfig(socksInPort: 10809);

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
}
