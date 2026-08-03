import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/proxy_node.dart';

/// Фиксированное имя TUN-адаптера — та же причина, что была у
/// одноимённой xray-константы: без него имя генерируется случайно при
/// каждом запуске, и адаптеры-призраки от прошлых сессий накапливаются
/// вместо переиспользования одного и того же.
const tunInterfaceName = 'flux-tun0';

/// Публичные резолверы, к которым браузеры ходят своим DoH (Chrome — «Secure
/// DNS», Firefox — DNS over HTTPS). Обращения к ним по 443 отбиваются, см.
/// объяснение у соответствующего route-правила. Список заведомо неполный —
/// он и не может быть полным, — но покрывает то, что реально включено по
/// умолчанию у подавляющего большинства.
const _knownDohEndpoints = [
  '8.8.8.8/32', // Google
  '8.8.4.4/32',
  '2001:4860:4860::8888/128',
  '2001:4860:4860::8844/128',
  '1.1.1.1/32', // Cloudflare
  '1.0.0.1/32',
  '2606:4700:4700::1111/128',
  '2606:4700:4700::1001/128',
  '9.9.9.9/32', // Quad9
  '149.112.112.112/32',
];

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
/// Основной outbound — SOCKS5 на локальный порт, где уже слушает xray-core в
/// Proxy-режиме (`socksInPort`). Реальный разговор с VLESS/Hysteria2-сервером
/// как вёл xray, так и продолжает вести — sing-box сам наружу к серверу
/// никогда не ходит.
///
/// IPv6-адрес в `address` обязателен по той же причине, что и в старом
/// xray-конфиге: без него `auto_route` не поставит `::/0`, а Windows по RFC
/// 6724 предпочитает IPv6 маршрут напрямую через реальный аплинк, если он у
/// провайдера есть — трафик к dual-stack сайтам утечёт мимо TUN.
///
/// `route.rules: [{protocol: dns, action: hijack-dns}]` обязательно: Windows
/// отправляет системные DNS-запросы на gateway-адрес TUN-интерфейса
/// (172.19.0.2 — сам по себе не существующий хост, просто peer-адрес /30
/// подсети), и без hijack-правила sing-box маршрутизирует эти пакеты как
/// обычный трафик на этот адрес — а не отвечает на них сам. Пакет улетает
/// через xray в тоннель на несуществующий хост и там и остаётся: имена не
/// резолвятся вообще ничем, что выглядит как полное отсутствие интернета
/// сразу после включения TUN.
///
/// Само hijack-правило матчится по порту 53, а не по `protocol: dns` из
/// сниффера: сниффер опознаёт как dns ещё и LLMNR (5355), mDNS (5353) и
/// NetBIOS-NS (137) — формат у них DNS-подобный, но реальным DNS-парсером они
/// не разбираются, и лог заполняется сотнями `process DNS packet: unpack
/// request: bad question name`. Порт 53 покрывает и UDP, и TCP.
///
/// Сниффинг при этом всё равно нужен, просто не ради hijack'а: он достаёт из
/// потока имя хоста и передаёт его xray вместо голого IP — иначе доменные
/// правила роутинга у сервера (`ServerLeaf.routingRules`, ROADMAP трек 3) в
/// TUN-режиме перестали бы срабатывать вообще.
///
/// Включается сниффинг именно правилом `route.rules` с `action: "sniff"`.
/// Раньше это было поле `sniff: true` прямо на inbound — в sing-box 1.13.0
/// такие legacy inbound-поля объявлены deprecated, а в 1.13.14 (текущий
/// фактический бинарник, см. assets/sing-box/SOURCE.md) уже физически убраны:
/// с `sniff` на inbound процесс падает при старте с `FATAL create service:
/// initialize inbound[0]: legacy inbound fields are deprecated` — и, поскольку
/// это происходит до поднятия TUN-адаптера, внешне выглядит ровно как «трафик
/// идёт мимо TUN» (адаптера просто нет).
///
/// ## Почему нужен `direct`-outbound и обход тоннеля для самого xray
///
/// Сначала казалось, что классическая проблема TUN «трафик срезает свой же
/// исходящий коннект в тот же тоннель» тут структурно не возникает, раз
/// единственный outbound sing-box смотрит на loopback. Это неверно: наружу к
/// VLESS-серверу ходит xray, и его собственный сокет `auto_route` заворачивает
/// в TUN наравне со всем прочим трафиком. Без обхода получается замкнутый
/// круг — xray'ю нужен тоннель, чтобы поднять тоннель:
///
/// 1. xray резолвит хост своего сервера через системный резолвер;
/// 2. запрос уходит в TUN (там теперь default route) → в sing-box;
/// 3. sing-box хиджекает его и идёт спрашивать свой upstream-DNS **через
///    `xray-socks-out`**;
/// 4. xray, чтобы обслужить этот SOCKS-запрос, должен подключиться к серверу,
///    для чего ему нужно… отрезолвить хост сервера — п.1.
///
/// Ровно это и наблюдалось в логах: все без исключения DNS-запросы отваливались
/// по таймауту в 10.0s (`dns: exchange failed ... context deadline exceeded`), и
/// первым в списке стоял хост самого VPN-сервера. Симптом — «после включения TUN
/// пропадает интернет», причём маршруты при этом настроены абсолютно правильно.
///
/// Разрывается это двумя независимыми механизмами, оба обязательны:
///
/// * `bootstrap`-DNS (DoT напрямую, минуя xray) + `dns.rules` на домен сервера
///   — чтобы резолв хоста сервера не зависел от тоннеля. Матчинг именно по
///   домену, а не по `process_name: xray.exe`: на Windows Go-резолвер ходит
///   через системную службу DNS Client, поэтому DNS-пакет на проводе принадлежит
///   `svchost.exe`, и правило по имени процесса для DNS не сработало бы.
/// * `route_exclude_address` на самом адресе сервера — чтобы уже установленное
///   TLS-соединение с сервером вообще не попадало в TUN. Плюс, как страховка на
///   случай, если сервер отрезолвится в адрес, которого в списке нет, —
///   `direct`-outbound по `process_name: xray.exe` и по тем же IP: тогда пакет
///   в TUN всё-таки войдёт, но будет развёрнут наружу, а не зациклен в xray.
///   Адреса (`serverIps`) резолвятся заранее, до поднятия TUN, см.
///   `TunBridgeEngine`.
///
/// DNS всего остального трафика по-прежнему идёт внутри тоннеля (`remote` с
/// `detour: xray-socks-out`), так что обход не превращается в DNS-утечку: мимо
/// тоннеля уходят только bootstrap-запросы про сам сервер, и те по DoT.
/// [routingRules] — правила роутинга активного `ServerLeaf`
/// (`ServerLeaf.routingRules`, ROADMAP.md трек 3/21) — генерируют
/// дополнительные `route.rules` **после** всех правил ниже (инфраструктурные
/// правила приоритетнее пользовательских). [ruleSetPaths] — пути к уже
/// сконвертированным JSON rule-set'ам geosite/geoip-категорий, на которые
/// эти правила могут ссылаться (`geosite:`/`geoip:`-значения) — ключ вида
/// `geosite-category-ads`/`geoip-cn` (см. [geoRuleSetReferences] и
/// `geo_ruleset_cache.dart`); резолвится и передаётся вызывающей стороной
/// (`SingBoxEngineWindows.start`), а не тут — эта функция остаётся чистой
/// синхронной, конвертация же асинхронная (читает файл с диска).
Map<String, dynamic> buildSingBoxTunBridgeConfig({
  required int socksInPort,
  required String serverHost,
  List<String> serverIps = const [],
  String upstreamDns = defaultTunDnsServer,
  CoreLogLevel logLevel = CoreLogLevel.warn,
  List<RoutingRule> routingRules = const [],
  Map<String, String> ruleSetPaths = const {},
  String defaultOutboundTag = 'proxy',
}) {
  return {
    'log': {'level': logLevel.singBoxName},
    'dns': {
      // Резолвим только в IPv4 — и это не «отключить IPv6 на всякий случай», а
      // прямой вывод из замеров одного сеанса: у соединений к IPv6-адресатам
      // медиана 1.24s против 0.01s у IPv4, максимум 6.24s, двадцать штук висели
      // дольше пяти секунд. При этом по IPv6 шло почти всё (179 соединений
      // против 19): TUN анонсирует ::/0, а Windows по RFC 6724 предпочитает
      // IPv6, когда он доступен. Убрав AAAA из ответов, мы уводим трафик на
      // быструю ветку, ничего не ломая: IPv6-адрес и маршрут на TUN остаются,
      // так что обращение к literal-IPv6 по-прежнему перехватывается и наружу
      // мимо тоннеля не утекает — просто больше никто туда не ходит.
      //
      // Проверено на живом бинарнике, а не по факту «конфиг принялся»: без
      // стратегии AAAA-запрос к хиджекнутому DNS отдаёт 4 записи, с ней — 0,
      // при неизменных 6 записях на A.
      'strategy': 'ipv4_only',
      'servers': [
        {
          'tag': 'remote',
          'type': 'tls',
          'server': upstreamDns,
          'detour': 'xray-socks-out',
        },
        // Без `detour` — и это именно то, что нужно, а не недосмотр: DNS-сервер
        // без detour дозванивается напрямую, минуя и `route.final`, и правила
        // роутинга вообще. Проверено на живом бинарнике: с заведомо мёртвым
        // `final` резолв через такой сервер всё равно проходит за ~120ms.
        // Явный `detour: direct` тут написать нельзя — sing-box 1.13 отвергает
        // его на старте (`start dns/tls[bootstrap]: detour to an empty direct
        // outbound makes no sense`), потому что это ровно то же самое.
        {'tag': 'bootstrap', 'type': 'tls', 'server': upstreamDns},
      ],
      'rules': [
        {
          'domain': [serverHost],
          'server': 'bootstrap',
        },
      ],
    },
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
        // Адрес сервера исключается из тоннеля на уровне системных маршрутов —
        // `auto_route` ставит на него отдельный, более специфичный маршрут через
        // физический шлюз. Без этого пакеты xray к серверу всё равно попадали в
        // TUN и разворачивались обратно наружу правилами ниже: работало, но
        // каждый байт тоннеля дважды проходил через userspace-стек gvisor, и в
        // логах это выглядело как пачка `connection upload closed: ... software
        // caused connection abort` на адресе сервера плюс страницы, грузящиеся
        // по 30-40 секунд. Правила ниже остаются страховкой на случай, если
        // сервер отрезолвится в адрес, которого тут нет.
        if (serverIps.isNotEmpty)
          'route_exclude_address': [
            for (final ip in serverIps) _asSingleHostCidr(ip),
          ],
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
      {'type': 'direct', 'tag': 'direct'},
      {'type': 'block', 'tag': 'block'},
    ],
    'route': {
      'rules': [
        {'inbound': 'tun-in', 'action': 'sniff'},
        // Мультикаст/бродкаст в тоннеле бессмыслен: заворачивать mDNS и NBNS в
        // зарубежный сервер нечего, а `auto_route` тянет в TUN и 224.0.0.0/4, и
        // 255.255.255.255. Режем до hijack-правила, иначе они доходят до
        // DNS-обработчика (формат у них DNS-подобный) и сыпят разбор.
        {
          'ip_cidr': ['224.0.0.0/4', '255.255.255.255/32'],
          'action': 'reject',
        },
        // Отбиваем браузерный DoH. Chrome со своим «Secure DNS» резолвит имена
        // сам, ходя на 8.8.8.8:443 в обход нашего хиджека — а значит в обход и
        // `ipv4_only`, и доменных правил роутинга: половина настроек тоннеля для
        // него просто не существует. Плюс наблюдаемый симптом: на части серверов
        // путь к этим адресам подвисает, и Chrome ждёт таймаута своей DoH-пробы
        // ~40 секунд, в течение которых навигация буксует, а любой сайт,
        // открытый следом, «чинит» её (Chrome пересобирает состояние).
        //
        // Именно поэтому в Proxy-режиме таких проблем не было ни на одном
        // сервере: при настроенном системном прокси Chrome свой DoH отключает
        // сам, и DNS всегда шёл через ядро.
        //
        // `reject` отвечает RST, и Chrome откатывается на системный резолвер
        // сразу, а не по таймауту. Наш собственный DoT к тому же 8.8.8.8 идёт по
        // 853 и под правило не попадает; DNS-серверы вдобавок дозваниваются в
        // обход route-правил, так что задеть их тут нечем.
        {
          'ip_cidr': _knownDohEndpoints,
          'port': 443,
          'action': 'reject',
        },
        // QUIC здесь СОЗНАТЕЛЬНО не блокируется, хотя напрашивается: какое-то
        // время тут стоял `{network: udp, port: 443, action: reject}`. Поводом
        // был шторм — 313 UDP-сессий за 70 секунд, все до одной на порт 443, из
        // них 226 в Google DoH. Выглядело как «UDP через мост не работает».
        //
        // На деле это был симптом другой болезни: тогда весь трафик шёл по
        // IPv6, а тот был на порядки медленнее (медиана 1.24s против 0.01s у
        // IPv4), и QUIC просто ретраился в этой медленной ветке. После
        // `dns.strategy: ipv4_only` причина ушла, а UDP-путь проверен отдельно:
        // через SOCKS-релей возвращается ответ в 1149 байт, то есть датаграммы
        // размера QUIC-хендшейка проходят.
        //
        // Если шторм вернётся — сначала смотреть, не уполз ли трафик обратно на
        // IPv6, и только потом снова резать QUIC: блокировка лечит симптом и
        // стоит потери HTTP/3.
        // Хиджек именно по порту, а не по `protocol: dns` из сниффера: LLMNR
        // (5355), mDNS (5353) и NetBIOS-NS (137) сниффер тоже опознаёт как dns,
        // после чего они не разбираются реальным DNS-парсером — в логе это была
        // сотня `process DNS packet: unpack request: bad question name: dns: bad
        // rdata`. Порт 53 покрывает и UDP, и TCP.
        {'port': 53, 'action': 'hijack-dns'},
        // Правила по `process_name` тут больше нет намеренно. Обход трафика
        // xray делают `route_exclude_address` (на уровне таблицы маршрутов) и
        // ip_cidr-правило ниже — оба по тем же адресам, так что сопоставление
        // по имени процесса было третьей копией той же страховки. При этом оно
        // заставляло sing-box на КАЖДОЕ соединение искать процесс-владельца, а
        // на Windows это перечисление всей таблицы TCP — плата, которую платил
        // весь трафик ради случая, уже покрытого дважды.
        if (serverIps.isNotEmpty)
          {
            'ip_cidr': [for (final ip in serverIps) _asSingleHostCidr(ip)],
            'outbound': 'direct',
          },
        // Пользовательские правила — намеренно последними: всё выше это
        // инфраструктурные страховки (мультикаст, DoH, hijack-dns, обход
        // адреса сервера), которые не должны переопределяться конфигом
        // сервиса.
        ..._userRoutingRules(routingRules),
      ],
      if (geoRuleSetReferences(routingRules).isNotEmpty)
        'rule_set': [
          for (final tag in geoRuleSetReferences(routingRules))
            {
              'type': 'local',
              'tag': tag,
              'format': 'source',
              'path': ruleSetPaths[tag] ??
                  (throw StateError('No rule_set path resolved for $tag')),
            },
        ],
      'auto_detect_interface': true,
      // Требуется с sing-box 1.12.0, если у какого-то outbound'а адрес может
      // потребовать резолва: без этого ключа процесс не стартует вообще
      // (`FATAL ... missing route.default_domain_resolver`). Здесь это
      // `bootstrap` по той же причине, по которой он вообще появился — резолв
      // для outbound'ов не должен зависеть от ещё не поднятого тоннеля.
      'default_domain_resolver': 'bootstrap',
      'final': _finalOutboundTag(defaultOutboundTag),
    },
  };
}

/// [defaultOutboundTag] — `RoutingPreset.defaultOutboundTag`
/// (`"proxy"`/`"direct"`/`"block"`, см. ROADMAP.md трек 3). `route.final`
/// требует именно тег outbound'а, а не `action` — поэтому у `"block"` тут
/// нет короткого пути через `reject`, как у обычных `route.rules`
/// (`_outboundOrAction`): вместо этого выше в `outbounds` заведён отдельный
/// `{type: "block", tag: "block"}`.
String _finalOutboundTag(String defaultOutboundTag) => switch (defaultOutboundTag) {
  'direct' => 'direct',
  'block' => 'block',
  _ => 'xray-socks-out',
};

/// Теги `geosite-<category>`/`geoip-<category>`, на которые нужно завести
/// `route.rule_set` — вызывающая сторона (`SingBoxEngineWindows.start`)
/// резолвит для каждого пути через `geo_ruleset_cache.dart` **до** вызова
/// [buildSingBoxTunBridgeConfig] (та асинхронная, эта — нет) и передаёт
/// результат как [ruleSetPaths].
Set<String> geoRuleSetReferences(List<RoutingRule> rules) {
  final tags = <String>{};
  for (final rule in rules) {
    switch (rule) {
      case DomainRule(:final values):
        for (final v in values) {
          if (v.startsWith('geosite:')) tags.add('geosite-${v.substring(8)}');
        }
      case IpRule(:final values):
        for (final v in values) {
          if (v.startsWith('geoip:')) tags.add('geoip-${v.substring(6)}');
        }
    }
  }
  return tags;
}

/// `outboundTag` из [RoutingRule] — `"direct"`/`"block"`/`"proxy"` (см.
/// ROADMAP.md, трек 3). `"proxy"` не даёт отдельного правила — `route.final`
/// уже шлёт туда всё непойманное, лишнее правило было бы балластом.
/// `"block"` — не outbound-тег в sing-box, а `action: "reject"`.
List<Map<String, dynamic>> _userRoutingRules(List<RoutingRule> rules) {
  final result = <Map<String, dynamic>>[];
  for (final rule in rules) {
    switch (rule) {
      case DomainRule(:final values, :final outboundTag):
        if (outboundTag == 'proxy') continue;
        final domain = <String>[];
        final domainSuffix = <String>[];
        final domainKeyword = <String>[];
        final domainRegex = <String>[];
        final geositeTags = <String>[];
        for (final v in values) {
          if (v.startsWith('geosite:')) {
            geositeTags.add('geosite-${v.substring(8)}');
          } else if (v.startsWith('full:')) {
            domain.add(v.substring(5));
          } else if (v.startsWith('domain:')) {
            domainSuffix.add(v.substring(7));
          } else if (v.startsWith('regexp:')) {
            domainRegex.add(v.substring(7));
          } else {
            domainKeyword.add(v);
          }
        }
        if (domain.isNotEmpty ||
            domainSuffix.isNotEmpty ||
            domainKeyword.isNotEmpty ||
            domainRegex.isNotEmpty) {
          result.add({
            if (domain.isNotEmpty) 'domain': domain,
            if (domainSuffix.isNotEmpty) 'domain_suffix': domainSuffix,
            if (domainKeyword.isNotEmpty) 'domain_keyword': domainKeyword,
            if (domainRegex.isNotEmpty) 'domain_regex': domainRegex,
            ..._outboundOrAction(outboundTag),
          });
        }
        if (geositeTags.isNotEmpty) {
          result.add({'rule_set': geositeTags, ..._outboundOrAction(outboundTag)});
        }
      case IpRule(:final values, :final outboundTag):
        if (outboundTag == 'proxy') continue;
        final ipCidr = <String>[];
        final geoipTags = <String>[];
        for (final v in values) {
          if (v.startsWith('geoip:')) {
            geoipTags.add('geoip-${v.substring(6)}');
          } else {
            ipCidr.add(v);
          }
        }
        if (ipCidr.isNotEmpty) {
          result.add({'ip_cidr': ipCidr, ..._outboundOrAction(outboundTag)});
        }
        if (geoipTags.isNotEmpty) {
          result.add({'rule_set': geoipTags, ..._outboundOrAction(outboundTag)});
        }
    }
  }
  return result;
}

Map<String, dynamic> _outboundOrAction(String outboundTag) =>
    outboundTag == 'block' ? {'action': 'reject'} : {'outbound': outboundTag};

/// `ip_cidr` требует именно префикс, а не голый адрес. Маска зависит от
/// семейства адреса: /32 для IPv4, /128 для IPv6.
String _asSingleHostCidr(String ip) => ip.contains(':') ? '$ip/128' : '$ip/32';
