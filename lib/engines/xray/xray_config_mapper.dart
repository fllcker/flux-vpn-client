import '../../core_abstraction/server_config.dart';

/// Фиксированное имя TUN-адаптера — без этого xray-core генерирует
/// случайное имя ("utunN") при каждом запуске, и в системе постепенно
/// накапливаются адаптеры-призраки от прошлых сессий вместо переиспользования
/// одного и того же.
const tunInterfaceName = 'flux0';

/// Строит xray-core JSON-конфиг для одного VLESS-сервера в Proxy-режиме
/// (Вариант B — локальный SOCKS/HTTP). Полноценный экспорт из дерева
/// ProxyNode/роутинга появится вместе с поддержкой групп и правил
/// маршрутизации — см. PLAN.md, "Единый формат конфига".
Map<String, dynamic> buildXrayConfig(
  ServerConfig server, {
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
    'outbounds': [_outbound(server), _directOutbound],
  };
}

/// Строит xray-core JSON-конфиг в TUN-режиме (Вариант A — полноценный VPN
/// через `wintun`, встроенный в xray-core inbound `tun`, см. PLAN.md,
/// "Системная интеграция VPN на Windows"). Требует прав администратора —
/// это проверяется до вызова, на уровне UI/контроллера подключения.
///
/// `autoOutboundsInterface: "auto"` обязателен — без него исходящий трафик
/// самого xray к VLESS-серверу тоже завернётся в TUN, получится петля.
///
/// IPv6-адрес и маршрут `::/0` обязательны, даже если апстрим не умеет в
/// IPv6: без них TUN ставит только IPv4-маршрут по умолчанию, а Windows по
/// RFC 6724 предпочитает IPv6, если он есть у провайдера — весь трафик к
/// dual-stack сайтам уходит напрямую мимо TUN, показывая настоящий IP,
/// хотя приложение считает себя подключённым (см. PLAN.md баг про утечку
/// в TUN-режиме). Лучше "закрыть" IPv6 в туннель и уронить такие
/// соединения, чем молча слить их в обход VPN.
Map<String, dynamic> buildXrayTunConfig(ServerConfig server) {
  return {
    'log': {'loglevel': 'warning'},
    'inbounds': [
      {
        'tag': 'tun-in',
        'port': 0,
        'protocol': 'tun',
        'settings': {
          'name': tunInterfaceName,
          'mtu': 1500,
          'gateway': ['10.10.10.1/24', 'fdfe:dcba:9876::1/126'],
          'dns': ['1.1.1.1', '8.8.8.8'],
          'autoSystemRoutingTable': ['0.0.0.0/0', '::/0'],
          'autoOutboundsInterface': 'auto',
        },
      },
    ],
    'outbounds': [_outbound(server), _directOutbound],
  };
}

const _directOutbound = {'protocol': 'freedom', 'tag': 'direct'};

Map<String, dynamic> _outbound(ServerConfig server) => switch (server) {
  VlessConfig server => _vlessOutbound(server),
  Hysteria2Config server => _hysteria2Outbound(server),
};

Map<String, dynamic> _vlessOutbound(VlessConfig server) => {
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
};

Map<String, dynamic> _streamSettings(VlessConfig server) {
  final network = switch (server.network) {
    VlessNetwork.tcp => 'tcp',
    VlessNetwork.xhttp => 'xhttp',
  };

  final settings = <String, dynamic>{'network': network};

  if (server.network == VlessNetwork.xhttp) {
    settings['xhttpSettings'] = {
      if (server.xhttpPath != null) 'path': server.xhttpPath,
      if (server.xhttpHost != null) 'host': server.xhttpHost,
      'mode': 'auto',
    };
  }

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

/// xray-core называет протокол `hysteria` (не `hysteria2`), `version: 2`
/// обязателен и в `settings`, и в `hysteriaSettings` — так xray-core
/// различает Hysteria v1/v2. `obfs` добавляется только если у сервера задан
/// пароль обфускации (Salamander опциональна, см. `Hysteria2Config`).
Map<String, dynamic> _hysteria2Outbound(Hysteria2Config server) => {
  'protocol': 'hysteria',
  'settings': {
    'version': 2,
    'address': server.address,
    'port': server.port,
  },
  'streamSettings': {
    'network': 'hysteria',
    'security': 'tls',
    'tlsSettings': {
      'serverName': server.sni ?? server.address,
      if (server.insecure) 'allowInsecure': true,
    },
    'hysteriaSettings': {
      'version': 2,
      'auth': server.auth,
      'udpIdleTimeout': 120,
      if (server.obfsPassword != null)
        'obfs': {'type': 'salamander', 'password': server.obfsPassword},
    },
  },
};
