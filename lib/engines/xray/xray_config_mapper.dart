import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';

/// Строит xray-core JSON-конфиг для одного VLESS-сервера в Proxy-режиме
/// (Вариант B — локальный SOCKS/HTTP). Полноценный экспорт из дерева
/// ProxyNode/роутинга появится вместе с поддержкой групп и правил
/// маршрутизации — см. PLAN.md, "Единый формат конфига".
Map<String, dynamic> buildXrayConfig(
  ServerConfig server, {
  required int socksPort,
  required int httpPort,
  List<RoutingRule> routingRules = const [],
  CoreLogLevel logLevel = CoreLogLevel.warn,
}) {
  return {
    'log': {'loglevel': logLevel.xrayName},
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
    'outbounds': [_outbound(server), _directOutbound, _blockOutbound],
    if (routingRules.isNotEmpty) 'routing': _routing(routingRules),
  };
}

/// Android TUN-конфиг — `tun`-инбаунд вместо SOCKS/HTTP, см.
/// `lib/engines/xray/xray_engine_android.dart`. В отличие от Windows,
/// xray-core сам умеет настраивать/читать TUN на Android (gVisor-стек,
/// `proxy/tun/tun_android.go`) через fd, переданный из `FluxVpnService`
/// (`xray.tun.fd`, см. `CoreController.startLoop`) — конфиг сам по себе
/// маршруты/адрес/DNS не описывает, это уже сделано на стороне
/// `VpnService.Builder` в Kotlin.
Map<String, dynamic> buildXrayTunConfig(
  ServerConfig server, {
  List<RoutingRule> routingRules = const [],
  CoreLogLevel logLevel = CoreLogLevel.warn,
  int mtu = 1500,
}) {
  return {
    'log': {'loglevel': logLevel.xrayName},
    'inbounds': [
      {
        'tag': 'tun-in',
        'port': 0,
        'protocol': 'tun',
        'settings': {'name': 'flux-tun0', 'MTU': mtu},
      },
    ],
    'outbounds': [_outbound(server), _directOutbound, _blockOutbound],
    if (routingRules.isNotEmpty) 'routing': _routing(routingRules),
  };
}

const _directOutbound = {'protocol': 'freedom', 'tag': 'direct'};
const _blockOutbound = {'protocol': 'blackhole', 'tag': 'block'};

/// `outboundTag` в [RoutingRule] — `"direct"`/`"block"`/`"proxy"` (см.
/// ROADMAP.md, трек 3) — совпадает с тегами outbound'ов один в один, кроме
/// `"proxy"`: сам сервер-outbound не имеет фиксированного тега на уровне
/// [ServerConfig] (он один и всегда первый в списке), поэтому проставляем
/// ему тег `"proxy"` здесь же, при сборке конфига.
Map<String, dynamic> _routing(List<RoutingRule> rules) => {
  'rules': [
    for (final rule in rules)
      switch (rule) {
        DomainRule(:final values, :final outboundTag) => {
          'type': 'field',
          'domain': values,
          'outboundTag': outboundTag,
        },
        IpRule(:final values, :final outboundTag) => {
          'type': 'field',
          'ip': values,
          'outboundTag': outboundTag,
        },
      },
  ],
};

Map<String, dynamic> _outbound(ServerConfig server) => switch (server) {
  VlessConfig server => _vlessOutbound(server),
  Hysteria2Config server => _hysteria2Outbound(server),
};

Map<String, dynamic> _vlessOutbound(VlessConfig server) => {
  'protocol': 'vless',
  'tag': 'proxy',
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
  'tag': 'proxy',
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
