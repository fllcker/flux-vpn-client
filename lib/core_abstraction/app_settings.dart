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

const _defaultPingTestUrl = 'https://www.gstatic.com/generate_204';

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

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.homeBackground = HomeBackground.globe,
    this.pingMode = PingMode.viaProxy,
    this.pingTestUrl = _defaultPingTestUrl,
    this.pingAllOnStartup = false,
    this.autoGroupSubscriptions = true,
    this.autoStartOnBoot = false,
    this.tunCoreType = TunCoreType.singBox,
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
      HomeBackground.globe,
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
