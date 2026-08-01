import 'connection_session.dart';

/// Тема оформления — `system` следует настройке ОС, см. [AppSettings].
enum AppThemeMode { system, light, dark }

/// Язык интерфейса — `system` следует локали ОС, см. [AppSettings].
enum AppLanguage { system, ru, en }

/// Фон главного экрана подключения (за карточкой Off/Proxy/TUN).
/// `simpleGradient`/`colorBends`/`galaxy` — шейдерные фоны, см.
/// ROADMAP.md, "Фон — шейдерные эффекты". `customVideo` — свой видеофайл
/// юзера (путь к копии — `AppSettings.customVideoPath`), см.
/// `video_background.dart`.
enum HomeBackground { none, globe, simpleGradient, colorBends, galaxy, customVideo }

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

/// Уровень привилегий автозапуска при входе в Windows — см. ROADMAP.md,
/// трек 24. `standard` — обычный реестровый `HKCU\...\Run` (не требует
/// прав администратора). `elevated` — Windows не даёт элевейтить процесс,
/// запущенный из `Run`, без интерактивного UAC на каждый вход, поэтому это
/// отдельный механизм — Scheduled Task с "Run with highest privileges" (см.
/// `windows_autostart.dart`), нужен для автозапуска в TUN-режиме
/// (`AppSettings.autoConnectMode`), раз TUN сам требует прав администратора.
enum AppAutoStartPrivilege { none, standard, elevated }

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

/// URL по умолчанию для geoip/geosite — см. `lib/engines/geo_assets.dart` и
/// ROADMAP.md, трек 20. Продублировано тут (а не импортировано оттуда) —
/// `app_settings.dart` часть `core_abstraction/`, не должна тянуть зависимость
/// на `lib/engines/`.
const defaultGeoipUrl =
    'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';
const defaultGeositeUrl =
    'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';

/// Настройки приложения — отдельно от [CoreConfig] (серверы/подписки):
/// это предпочтения интерфейса и поведения, не часть профиля, которым можно
/// было бы поделиться. Хранятся в своём файле, см. `app_settings_storage.dart`.
class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;
  final HomeBackground homeBackground;
  final PingMode pingMode;
  final String pingTestUrl;
  final bool pingAllOnStartup;
  final bool autoGroupSubscriptions;
  final AppAutoStartPrivilege autoStartPrivilege;

  /// Показывать окно при автозапуске — `false` (дефолт) означает окно
  /// остаётся скрытым, приложение доступно только через трей (см.
  /// ROADMAP.md, трек 24). Актуально только при `autoStartPrivilege !=
  /// none` — сам по себе флаг ни на что не влияет.
  final bool autoStartShowWindow;

  /// Автоматически подключаться к последнему выбранному серверу
  /// (`lastSelectedServerId`, трек 9) после запуска — не привязано к
  /// автозапуску: работает и при обычном ручном запуске приложения.
  final bool autoConnectOnStartup;

  /// Режим для автоподключения — `tun` реально используется, только если
  /// `autoStartPrivilege == elevated` (TUN требует прав администратора);
  /// UI (`settings_page.dart`) ограничивает выбор соответственно, а
  /// `connection_screen.dart` дополнительно подстраховывается на рантайме
  /// (`isRunningElevated()`), откатываясь на `proxy`, если элевейтед-задача
  /// автозапуска почему-то не сработала.
  final ConnectionMode autoConnectMode;

  /// Системные Windows-уведомления при подключении/отключении/ошибке (см.
  /// ROADMAP.md, трек 25) — `true` по умолчанию, это и есть сама фича, не
  /// скрытая опция; тумблер даёт отключить, если мешают.
  final bool showNotifications;

  final TunCoreType tunCoreType;

  /// Апстрим-резолвер TUN-режима. В Proxy-режиме не используется намеренно:
  /// там xray домены вообще не резолвит, а отдаёт их серверу, который и
  /// резолвит на своей стороне — настройка «DNS для прокси» была бы ручкой,
  /// которая ни на что не влияет.
  final String tunDnsServer;
  final CoreLogLevel coreLogLevel;

  /// Кастомные ссылки на `geoip.dat`/`geosite.dat` — см. ROADMAP.md, трек 20.
  /// По умолчанию — тот же апстрим, что раньше неявно ехал внутри
  /// `Xray-windows-64.zip`.
  final String geoipUrl;
  final String geositeUrl;

  /// Id последнего выбранного сервера (`ServerLeaf.id`) — предпочтение этой
  /// машины, не часть Magic JSON-профиля, которым можно поделиться (см.
  /// ROADMAP.md, трек 9). Восстанавливается на старте, но только если id ещё
  /// существует в текущем дереве — сервер могли удалить из подписки между
  /// запусками.
  final String? lastSelectedServerId;

  /// Путь к скопированному видеофайлу для `HomeBackground.customVideo` —
  /// абсолютный путь внутри аппдаты (`video_background_storage.dart`), не
  /// оригинальный путь, который выбрал юзер (тот может быть на съёмном
  /// диске/временной папке и исчезнуть). `null`, если файл ещё не выбран —
  /// тогда `customVideo` в UI ведёт себя как `none`.
  final String? customVideoPath;

  /// Первый запуск показывает онбординг (`lib/features/onboarding/`) вместо
  /// `ConnectionScreen` — см. `main.dart`. Дефолт этого поля НАРОЧНО разный
  /// между конструктором (`false`) и `fromJson` (`true`, см. ниже): если
  /// одинаково завести `false` и там, и там, все уже существующие установки
  /// (settings.json уже на диске у пользователей версии 1.1.0) увидят
  /// онбординг из ниоткуда при обновлении — конструктор используется только
  /// когда файла ещё вовсе не было (реально первый запуск), а `fromJson` —
  /// когда файл есть, но поля в нём нет (апгрейд с версии до онбординга).
  final bool onboardingCompleted;

  /// Id активного пресета роутинга (`CoreConfig.routingPresets`) — локальное
  /// предпочтение машины, как [lastSelectedServerId], не часть Magic JSON
  /// профиля. `null` — специальный пресет "Роутинг сервера": каждый сервер
  /// использует свой `ServerLeaf.routingRules` как раньше (дефолт,
  /// воспроизводит поведение до реворка роутинга на пресеты).
  final String? activeRoutingPresetId;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.language = AppLanguage.system,
    this.homeBackground = HomeBackground.galaxy,
    this.pingMode = PingMode.viaProxy,
    this.pingTestUrl = _defaultPingTestUrl,
    this.pingAllOnStartup = false,
    this.autoGroupSubscriptions = true,
    this.autoStartPrivilege = AppAutoStartPrivilege.none,
    this.autoStartShowWindow = false,
    this.autoConnectOnStartup = false,
    this.autoConnectMode = ConnectionMode.proxy,
    this.showNotifications = true,
    this.tunCoreType = TunCoreType.singBox,
    this.tunDnsServer = defaultTunDnsServer,
    this.coreLogLevel = CoreLogLevel.warn,
    this.geoipUrl = defaultGeoipUrl,
    this.geositeUrl = defaultGeositeUrl,
    this.lastSelectedServerId,
    this.customVideoPath,
    this.onboardingCompleted = false,
    this.activeRoutingPresetId,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: _enumFromJson(
      AppThemeMode.values,
      json['themeMode'],
      AppThemeMode.dark,
    ),
    language: _enumFromJson(
      AppLanguage.values,
      json['language'],
      AppLanguage.system,
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
    autoStartPrivilege: json['autoStartPrivilege'] != null
        ? _enumFromJson(
            AppAutoStartPrivilege.values,
            json['autoStartPrivilege'],
            AppAutoStartPrivilege.none,
          )
        // Апгрейд с версии до этого трека — старое булево поле означало
        // именно обычный (non-elevated) автозапуск, elevated тогда не
        // существовал вовсе.
        : ((json['autoStartOnBoot'] as bool?) == true
              ? AppAutoStartPrivilege.standard
              : AppAutoStartPrivilege.none),
    autoStartShowWindow: json['autoStartShowWindow'] as bool? ?? false,
    autoConnectOnStartup: json['autoConnectOnStartup'] as bool? ?? false,
    autoConnectMode: _enumFromJson(
      ConnectionMode.values,
      json['autoConnectMode'],
      ConnectionMode.proxy,
    ),
    showNotifications: json['showNotifications'] as bool? ?? true,
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
    geoipUrl: json['geoipUrl'] as String? ?? defaultGeoipUrl,
    geositeUrl: json['geositeUrl'] as String? ?? defaultGeositeUrl,
    lastSelectedServerId: json['lastSelectedServerId'] as String?,
    customVideoPath: json['customVideoPath'] as String?,
    // ?? true, не ?? false — см. комментарий у поля: отсутствие ключа тут
    // значит "апгрейд с версии, где онбординга не было", а не "первый
    // запуск" (тот идёт через конструктор напрямую, когда файла нет вовсе).
    onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
    activeRoutingPresetId: json['activeRoutingPresetId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'language': language.name,
    'homeBackground': homeBackground.name,
    'pingMode': pingMode.name,
    'pingTestUrl': pingTestUrl,
    'pingAllOnStartup': pingAllOnStartup,
    'autoGroupSubscriptions': autoGroupSubscriptions,
    'autoStartPrivilege': autoStartPrivilege.name,
    'autoStartShowWindow': autoStartShowWindow,
    'autoConnectOnStartup': autoConnectOnStartup,
    'autoConnectMode': autoConnectMode.name,
    'showNotifications': showNotifications,
    'tunCoreType': tunCoreType.name,
    'tunDnsServer': tunDnsServer,
    'coreLogLevel': coreLogLevel.name,
    'geoipUrl': geoipUrl,
    'geositeUrl': geositeUrl,
    if (lastSelectedServerId != null) 'lastSelectedServerId': lastSelectedServerId,
    if (customVideoPath != null) 'customVideoPath': customVideoPath,
    'onboardingCompleted': onboardingCompleted,
    if (activeRoutingPresetId != null)
      'activeRoutingPresetId': activeRoutingPresetId,
  };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    HomeBackground? homeBackground,
    PingMode? pingMode,
    String? pingTestUrl,
    bool? pingAllOnStartup,
    bool? autoGroupSubscriptions,
    AppAutoStartPrivilege? autoStartPrivilege,
    bool? autoStartShowWindow,
    bool? autoConnectOnStartup,
    ConnectionMode? autoConnectMode,
    bool? showNotifications,
    TunCoreType? tunCoreType,
    String? tunDnsServer,
    CoreLogLevel? coreLogLevel,
    String? geoipUrl,
    String? geositeUrl,
    String? lastSelectedServerId,
    String? customVideoPath,
    // Обычный `?? this.` не даёт стереть путь (null означает "не менять",
    // как везде в этом copyWith) — а стирать нужно, когда юзер убирает
    // видеофон (см. `settings_page.dart`, `_clearCustomVideo`).
    bool clearCustomVideoPath = false,
    bool? onboardingCompleted,
    String? activeRoutingPresetId,
    // Как `clearCustomVideoPath`: обычный `?? this.` не даёт вернуться к
    // пресету "Роутинг сервера" (null), раз null здесь и так значит "не
    // менять" — см. `settings_page.dart`.
    bool clearActiveRoutingPresetId = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      homeBackground: homeBackground ?? this.homeBackground,
      pingMode: pingMode ?? this.pingMode,
      pingTestUrl: pingTestUrl ?? this.pingTestUrl,
      pingAllOnStartup: pingAllOnStartup ?? this.pingAllOnStartup,
      autoGroupSubscriptions:
          autoGroupSubscriptions ?? this.autoGroupSubscriptions,
      autoStartPrivilege: autoStartPrivilege ?? this.autoStartPrivilege,
      autoStartShowWindow: autoStartShowWindow ?? this.autoStartShowWindow,
      autoConnectOnStartup: autoConnectOnStartup ?? this.autoConnectOnStartup,
      autoConnectMode: autoConnectMode ?? this.autoConnectMode,
      showNotifications: showNotifications ?? this.showNotifications,
      tunCoreType: tunCoreType ?? this.tunCoreType,
      tunDnsServer: tunDnsServer ?? this.tunDnsServer,
      coreLogLevel: coreLogLevel ?? this.coreLogLevel,
      geoipUrl: geoipUrl ?? this.geoipUrl,
      geositeUrl: geositeUrl ?? this.geositeUrl,
      lastSelectedServerId: lastSelectedServerId ?? this.lastSelectedServerId,
      customVideoPath: clearCustomVideoPath
          ? null
          : (customVideoPath ?? this.customVideoPath),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      activeRoutingPresetId: clearActiveRoutingPresetId
          ? null
          : (activeRoutingPresetId ?? this.activeRoutingPresetId),
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
