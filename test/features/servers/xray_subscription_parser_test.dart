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
    "remarks": "Sweden hysteria2",
    "outbounds": [
      {
        "tag": "proxy",
        "protocol": "hysteria",
        "settings": {"address": "se1.example.com", "port": 443},
        "streamSettings": {
          "security": "tls",
          "tlsSettings": {"serverName": "se1.example.com", "allowInsecure": true},
          "hysteriaSettings": {
            "version": 2,
            "auth": "hy2-password",
            "obfs": {"type": "salamander", "password": "obfs-password"}
          }
        }
      },
      {"tag": "direct", "protocol": "freedom"}
    ]
  },
  {
    "remarks": "Unsupported shadowsocks",
    "outbounds": [
      {"tag": "proxy", "protocol": "shadowsocks", "settings": {}, "streamSettings": {}},
      {"tag": "direct", "protocol": "freedom"}
    ]
  }
]
''';

void main() {
  test('parses a real-world-shaped xray-json subscription array', () {
    final result = parseXraySubscription(_sampleXrayArray);

    expect(result.servers, hasLength(3));
    expect(result.skipped, hasLength(1));
    expect(result.skipped.single.label, 'Unsupported shadowsocks');

    final germany = result.servers[0].config as VlessConfig;
    expect(result.servers[0].name, 'Germany #1');
    expect(germany.address, 'de1.example.com');
    expect(germany.security, VlessSecurity.reality);
    expect(germany.flow, 'xtls-rprx-vision');

    final poland = result.servers[1].config as VlessConfig;
    expect(poland.network, VlessNetwork.xhttp);
    expect(poland.xhttpPath, '/api');
    expect(poland.xhttpHost, 'cdn.example.com');

    final sweden = result.servers[2].config as Hysteria2Config;
    expect(result.servers[2].name, 'Sweden hysteria2');
    expect(sweden.address, 'se1.example.com');
    expect(sweden.auth, 'hy2-password');
    expect(sweden.sni, 'se1.example.com');
    expect(sweden.insecure, isTrue);
    expect(sweden.obfsPassword, 'obfs-password');
  });

  test('parses a single xray-json config object (not wrapped in an array)', () {
    final single = jsonDecode(_sampleXrayArray)[0];
    final result = parseXraySubscription(jsonEncode(single));

    expect(result.servers, hasLength(1));
    expect(result.servers.single.config.address, 'de1.example.com');
  });
}
