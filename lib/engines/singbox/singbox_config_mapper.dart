/// Фиксированное имя TUN-адаптера — та же причина, что была у
/// одноимённой xray-константы: без него имя генерируется случайно при
/// каждом запуске, и адаптеры-призраки от прошлых сессий накапливаются
/// вместо переиспользования одного и того же.
const tunInterfaceName = 'flux-tun0';

/// Строит конфиг sing-box, где sing-box — это не второе протокольное ядро,
/// а чистый packet-capture мост перед уже работающим xray в Proxy-режиме
/// (см. PLAN.md/ROADMAP про TUN на Windows и docs/fix_tun/). xray-core на
/// Windows умеет поднять `tun`-inbound адаптер, но физически не настраивает
/// на нём ни IP, ни маршруты (актуальная версия xray-core игнорирует любые
/// ключи вида gateway/dns/autoSystemRoutingTable — Windows выдаёт адаптеру
/// APIPA, `0.0.0.0/0` через него никогда не появляется). У sing-box же
/// `auto_route` полностью автоматически настраивает и адрес интерфейса, и
/// системные маршруты — см. docs/fix_tun/test3, где именно так и
/// происходит.
///
/// Единственный outbound — SOCKS5 на локальный порт, где уже слушает
/// xray-core в Proxy-режиме (`socksInPort`). Реальный разговор с
/// VLESS/Hysteria2-сервером как вёл xray, так и продолжает вести — sing-box
/// никогда не открывает соединение наружу напрямую, только на loopback,
/// поэтому классическая проблема TUN-режима "трафик срезает свой же исходящий
/// коннект в тот же тоннель" тут структурно не возникает (в отличие от
/// xray-шного `autoOutboundsInterface`, который как раз для неё был нужен).
///
/// IPv6-адрес в `address` обязателен по той же причине, что и в старом
/// xray-конфиге: без него `auto_route` не поставит `::/0`, а Windows по RFC
/// 6724 предпочитает IPv6 маршрут напрямую через реальный аплинк, если он у
/// провайдера есть — трафик к dual-stack сайтам утечёт мимо TUN.
Map<String, dynamic> buildSingBoxTunBridgeConfig({required int socksInPort}) {
  return {
    'log': {'level': 'warn'},
    'inbounds': [
      {
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': tunInterfaceName,
        'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
        'mtu': 1500,
        'auto_route': true,
        'strict_route': true,
        'stack': 'gvisor',
      },
    ],
    'outbounds': [
      {
        'type': 'socks',
        'tag': 'xray-socks-out',
        'server': '127.0.0.1',
        'server_port': socksInPort,
        'version': '5',
      },
    ],
    'route': {'auto_detect_interface': true, 'final': 'xray-socks-out'},
  };
}
