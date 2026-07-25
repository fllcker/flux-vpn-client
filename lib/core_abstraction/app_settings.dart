/// Тема оформления — `system` следует настройке ОС, см. [AppSettings].
enum AppThemeMode { system, light, dark }

/// Фон главного экрана подключения (за карточкой Off/Proxy/TUN).
/// `simpleGradient`/`colorBends`/`galaxy` — шейдерные фоны, см.
/// ROADMAP.md, "Фон — шейдерные эффекты".
enum HomeBackground { none, globe, simpleGradient, colorBends, galaxy }

/// Способ проверки пинга сервера — как в Happ: через локальный
/// прокси-порт xray (реальная задержка "как будет ощущаться"), напрямую по
/// TCP до `address:port` сервера (без ядра), или ICMP-эхо.
enum PingMode { viaProxy, tcp, icmp }

/// Какое ядро отвечает за TUN-адаптер/маршруты — не то же самое, что
/// протокольное ядро (VLESS/Hysteria2 всегда говорит xray, см.
/// `lib/engines/singbox/tun_bridge_engine.dart`). Пока единственный
/// вариант — sing-box, но точка расширения сделана явной специально: enum,
/// а не хардкод, чтобы второй вариант добавлялся без переписывания
/// контроллера подключения.
enum TunCoreType { singBox }

/// Подробность логов ядер. Значения общие для xray и sing-box, хотя называют
/// они их по-разному — маппинг в [CoreLogLevel.singBoxName]/[xrayName].
///
/// `debug` осмысленно держать под рукой, а не только в исходниках: почти вся
/// диагностика TUN-режима (что с чем не соединилось, куда ушёл резолв, сколько
/// жило соединение) видна только на нём, а на `warn` ядро про обычный трафик
/// молчит вовсе. Платой идёт объём — счёт идёт на сотни килобайт за минуты.
enum CoreLogLevel { error, warn, info, debug }

extension CoreLogLevelNames on CoreLogLevel {
  String get singBoxName => name;

  /// xray называет этот уровень `warning`, остальные совпадают.
  String get xrayName => this == CoreLogLevel.warn ? 'warning' : name;
}

const _defaultPingTestUrl = 'https://www.gstatic.com/generate_204';

/// DNS по умолчанию для TUN-режима. Обращение к нему идёт по IP (резолвить
/// сам резолвер было бы замкнутым кругом), а DoT поверх этого держится на том,
/// что сертификат `dns.google` выписан в том числе на 8.8.8.8 — у
/// произвольного провайдера так может и не быть, см.
/// `singbox_config_mapper.dart`.
const defaultTunDnsServer = '8.8.8.8';

/// Настройки приложения — отдельно от [CoreConfig] (серверы/подписки):
/// это предпочтения интерфейса и поведения, не часть профиля, которым можно
/// было бы поделиться. Хранятся в своём файле, см. `app_settings_storage.dart`.
class AppSettings {
  final AppThemeMode themeMode;
  final HomeBackground homeBackground;
  final PingMode pingMode;
  final String pingTestUrl;
  final bool pingAllOnStartup;
  final bool autoGroupSubscriptions;
  final bool autoStartOnBoot;
  final TunCoreType tunCoreType;

  /// Апстрим-резолвер TUN-режима. В Proxy-режиме не используется намеренно:
  /// там xray домены вообще не резолвит, а отдаёт их серверу, который и
  /// резолвит на своей стороне — настройка «DNS для прокси» была бы ручкой,
  /// которая ни на что не влияет.
  final String tunDnsServer;
  final CoreLogLevel coreLogLevel;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.homeBackground = HomeBackground.galaxy,
    this.pingMode = PingMode.viaProxy,
    this.pingTestUrl = _defaultPingTestUrl,
    this.pingAllOnStartup = false,
    this.autoGroupSubscriptions = true,
    this.autoStartOnBoot = false,
    this.tunCoreType = TunCoreType.singBox,
    this.tunDnsServer = defaultTunDnsServer,
    this.coreLogLevel = CoreLogLevel.warn,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: _enumFromJson(
      AppThemeMode.values,
      json['themeMode'],
      AppThemeMode.system,
    ),
    homeBackground: _enumFromJson(
      HomeBackground.values,
      json['homeBackground'],
      HomeBackground.galaxy,
    ),
    pingMode: _enumFromJson(
      PingMode.values,
      json['pingMode'],
      PingMode.viaProxy,
    ),
    pingTestUrl: json['pingTestUrl'] as String? ?? _defaultPingTestUrl,
    pingAllOnStartup: json['pingAllOnStartup'] as bool? ?? false,
    autoGroupSubscriptions: json['autoGroupSubscriptions'] as bool? ?? true,
    autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
    tunCoreType: _enumFromJson(
      TunCoreType.values,
      json['tunCoreType'],
      TunCoreType.singBox,
    ),
    tunDnsServer: json['tunDnsServer'] as String? ?? defaultTunDnsServer,
    coreLogLevel: _enumFromJson(
      CoreLogLevel.values,
      json['coreLogLevel'],
      CoreLogLevel.warn,
    ),
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'homeBackground': homeBackground.name,
    'pingMode': pingMode.name,
    'pingTestUrl': pingTestUrl,
    'pingAllOnStartup': pingAllOnStartup,
    'autoGroupSubscriptions': autoGroupSubscriptions,
    'autoStartOnBoot': autoStartOnBoot,
    'tunCoreType': tunCoreType.name,
    'tunDnsServer': tunDnsServer,
    'coreLogLevel': coreLogLevel.name,
  };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    HomeBackground? homeBackground,
    PingMode? pingMode,
    String? pingTestUrl,
    bool? pingAllOnStartup,
    bool? autoGroupSubscriptions,
    bool? autoStartOnBoot,
    TunCoreType? tunCoreType,
    String? tunDnsServer,
    CoreLogLevel? coreLogLevel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      homeBackground: homeBackground ?? this.homeBackground,
      pingMode: pingMode ?? this.pingMode,
      pingTestUrl: pingTestUrl ?? this.pingTestUrl,
      pingAllOnStartup: pingAllOnStartup ?? this.pingAllOnStartup,
      autoGroupSubscriptions:
          autoGroupSubscriptions ?? this.autoGroupSubscriptions,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      tunCoreType: tunCoreType ?? this.tunCoreType,
      tunDnsServer: tunDnsServer ?? this.tunDnsServer,
      coreLogLevel: coreLogLevel ?? this.coreLogLevel,
    );
  }
}

T _enumFromJson<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
