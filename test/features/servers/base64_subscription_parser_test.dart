import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core_abstraction/server_config.dart';
import 'package:vpn_client/features/servers/base64_subscription_parser.dart';

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
    final germanyConfig = germany.config;
    expect(germanyConfig.address, 'de1.example.com');
    expect(germanyConfig.security, VlessSecurity.reality);
    expect(germanyConfig.publicKey, 'pbk');

    final poland = result.servers[1];
    expect(poland.config.network, VlessNetwork.xhttp);
    expect(poland.config.xhttpPath, '/api');
    expect(poland.config.xhttpHost, 'cdn.example.com');
  });

  test('falls back to plain text when body is not valid base64', () {
    const body =
        'vless://uuid-1@de1.example.com:443?type=tcp&security=none#Plain';

    final result = parseBase64Subscription(body);

    expect(result.servers, hasLength(1));
    expect(result.servers.single.name, 'Plain');
  });
}
