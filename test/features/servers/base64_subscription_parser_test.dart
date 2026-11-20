import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/engines/singbox/singbox_config_mapper.dart';
import 'package:flux/engines/singbox/tun_server_endpoints.dart';
import 'package:flux/engines/xray/xray_config_mapper.dart';
import 'package:flux/features/servers/base64_subscription_parser.dart';

void main() {
  test('decodes a base64 body with mixed supported/unsupported links', () {
    const links = [
      'vless://uuid-1@de1.example.com:443'
          '?type=tcp&security=reality&sni=example.com&pbk=pbk&sid=sid&fp=chrome'
          '&flow=xtls-rprx-vision#Germany%20%231',
      'ss://something-unrelated#Shadowsocks',
      'vless://uuid-2@pl1.example.com:8443?type=xhttp&security=tls&path=%2Fapi&host=cdn.example.com#Poland',
    ];
    final body = base64.encode(utf8.encode(links.join('\n')));

    final result = parseBase64Subscription(body);

    expect(result.servers, hasLength(2));
    expect(result.skipped, hasLength(1));
    expect(result.skipped.single.label, 'ss');

    final germany = result.servers[0];
    expect(germany.name, 'Germany #1');
    final germanyConfig = germany.config as VlessConfig;
    expect(germanyConfig.address, 'de1.example.com');
    expect(germanyConfig.security, VlessSecurity.reality);
    expect(germanyConfig.publicKey, 'pbk');

    final poland = result.servers[1].config as VlessConfig;
    expect(poland.network, VlessNetwork.xhttp);
    expect(poland.xhttpPath, '/api');
    expect(poland.xhttpHost, 'cdn.example.com');
  });

  test('falls back to plain text when body is not valid base64', () {
    const body =
        'vless://uuid-1@de1.example.com:443?type=tcp&security=none#Plain';

    final result = parseBase64Subscription(body);

    expect(result.servers, hasLength(1));
    expect(result.servers.single.name, 'Plain');
  });

  test(
    'preserves XHTTP link settings and bypasses TUN for both endpoints',
    () async {
      final extra = Uri.encodeQueryComponent(
        jsonEncode({
          'headers': {'X-Test': 'one'},
          'downloadSettings': {'address': '198.51.100.2'},
        }),
      );
      final result = parseBase64Subscription(
        'vless://id@192.0.2.1:443?type=splithttp&security=tls'
        '&host=cdn.example.com&path=%2Fapi&mode=stream-up&alpn=h2'
        '&pcs=${'a' * 64}&extra=$extra',
      );
      final stored = ServerConfig.fromJson(
        jsonDecode(jsonEncode(result.servers.single.config.toJson()))
            as Map<String, dynamic>,
      );
      final config = buildXrayConfig(stored, socksPort: 10808, httpPort: 10809);
      final stream =
          (config['outbounds'] as List).first['streamSettings'] as Map;

      expect(stream['network'], 'xhttp');
      expect(stream['xhttpSettings'], {
        'mode': 'stream-up',
        'path': '/api',
        'host': 'cdn.example.com',
        'headers': {'X-Test': 'one'},
        'downloadSettings': {'address': '198.51.100.2'},
      });
      expect(stream['tlsSettings']['alpn'], ['h2']);
      expect(stream['tlsSettings']['pinnedPeerCertSha256'], 'a' * 64);

      final endpoints = await resolveTunServerEndpoints(stored);
      final tun = buildSingBoxTunBridgeConfig(
        socksInPort: 10808,
        serverHost: stored.address,
        additionalServerHosts: endpoints.additionalHosts,
        serverIps: endpoints.ips,
      );
      expect(tun['dns']['rules'].single['domain'], [
        '192.0.2.1',
        '198.51.100.2',
      ]);
      expect(tun['inbounds'].single['route_exclude_address'], [
        '192.0.2.1/32',
        '198.51.100.2/32',
      ]);
    },
  );

  test('skips only the link with malformed XHTTP extra', () {
    final result = parseBase64Subscription(
      'vless://id@example.com:443?type=xhttp&extra=%5B%5D\n'
      'vless://id@other.example.com:443?type=tcp',
    );
    expect(result.servers.single.config.address, 'other.example.com');
    expect(result.skipped.single.reason, contains('XHTTP'));
  });
}
