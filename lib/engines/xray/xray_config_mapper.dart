import '../../core_abstraction/server_config.dart';

/// Строит xray-core JSON-конфиг для одного VLESS-сервера. Полноценный
/// экспорт из дерева ProxyNode/роутинга появится вместе с поддержкой групп
/// и правил маршрутизации — см. PLAN.md, "Единый формат конфига".
Map<String, dynamic> buildXrayConfig(
  VlessConfig server, {
  required int socksPort,
  required int httpPort,
}) {
  return {
    'log': {'loglevel': 'warning'},
    'inbounds': [
      {
        'listen': '127.0.0.1',
        'port': socksPort,
        'protocol': 'socks',
        'settings': {'udp': true},
      },
      {
        'listen': '127.0.0.1',
        'port': httpPort,
        'protocol': 'http',
      },
    ],
    'outbounds': [
      {
        'protocol': 'vless',
        'settings': {
          'vnext': [
            {
              'address': server.address,
              'port': server.port,
              'users': [
                {
                  'id': server.uuid,
                  'encryption': 'none',
                  if (server.flow != null) 'flow': server.flow,
                },
              ],
            },
          ],
        },
        'streamSettings': _streamSettings(server),
      },
      {'protocol': 'freedom', 'tag': 'direct'},
    ],
  };
}

Map<String, dynamic> _streamSettings(VlessConfig server) {
  final network = switch (server.network) {
    VlessNetwork.tcp => 'tcp',
    VlessNetwork.xhttp => 'xhttp',
  };

  final settings = <String, dynamic>{'network': network};

  switch (server.security) {
    case VlessSecurity.none:
      settings['security'] = 'none';
    case VlessSecurity.tls:
      settings['security'] = 'tls';
      settings['tlsSettings'] = {
        if (server.sni != null) 'serverName': server.sni,
        if (server.fingerprint != null) 'fingerprint': server.fingerprint,
      };
    case VlessSecurity.reality:
      settings['security'] = 'reality';
      settings['realitySettings'] = {
        if (server.sni != null) 'serverName': server.sni,
        if (server.publicKey != null) 'publicKey': server.publicKey,
        if (server.shortId != null) 'shortId': server.shortId,
        if (server.fingerprint != null) 'fingerprint': server.fingerprint,
      };
  }

  return settings;
}
