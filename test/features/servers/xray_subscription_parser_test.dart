import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/xray_subscription_parser.dart';

/// Форма конфигов взята из реальной xray-json подписки (проверено вручную,
/// сама подписка в репозиторий не попадает).
const _sampleXrayArray = '''
[
  {
    "remarks": "Germany #1",
    "outbounds": [
      {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": "de1.example.com",
              "port": 443,
              "users": [
                {"id": "uuid-1", "encryption": "none", "flow": "xtls-rprx-vision"}
              ]
            }
          ]
        },
        "streamSettings": {
          "network": "tcp",
          "security": "reality",
          "realitySettings": {
            "serverName": "example.com",
            "publicKey": "pbk",
            "shortId": "sid",
            "fingerprint": "firefox"
          }
        }
      },
      {"tag": "direct", "protocol": "freedom"},
      {"tag": "block", "protocol": "blackhole"}
    ]
  },
  {
    "remarks": "Poland xhttp",
    "outbounds": [
      {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": "pl1.example.com",
              "port": 8443,
              "users": [{"id": "uuid-2", "encryption": "none"}]
            }
          ]
        },
        "streamSettings": {
          "network": "xhttp",
          "security": "reality",
          "realitySettings": {
            "serverName": "example.com",
            "publicKey": "pbk2",
            "shortId": "sid2",
            "fingerprint": "chrome"
          },
          "xhttpSettings": {"path": "/api", "host": "cdn.example.com", "mode": "auto"}
        }
      },
      {"tag": "direct", "protocol": "freedom"}
    ]
  },
  {
    "remarks": "Unsupported hysteria",
    "outbounds": [
      {"tag": "proxy", "protocol": "hysteria", "settings": {}, "streamSettings": {}},
      {"tag": "direct", "protocol": "freedom"}
    ]
  }
]
''';

void main() {
  test('parses a real-world-shaped xray-json subscription array', () {
    final result = parseXraySubscription(_sampleXrayArray);

    expect(result.servers, hasLength(2));
    expect(result.skipped, hasLength(1));
    expect(result.skipped.single.label, 'Unsupported hysteria');

    final germany = result.servers[0];
    expect(germany.name, 'Germany #1');
    expect(germany.config.address, 'de1.example.com');
    expect(germany.config.security, VlessSecurity.reality);
    expect(germany.config.flow, 'xtls-rprx-vision');

    final poland = result.servers[1];
    expect(poland.config.network, VlessNetwork.xhttp);
    expect(poland.config.xhttpPath, '/api');
    expect(poland.config.xhttpHost, 'cdn.example.com');
  });

  test('parses a single xray-json config object (not wrapped in an array)', () {
    final single = jsonDecode(_sampleXrayArray)[0];
    final result = parseXraySubscription(jsonEncode(single));

    expect(result.servers, hasLength(1));
    expect(result.servers.single.config.address, 'de1.example.com');
  });
}
