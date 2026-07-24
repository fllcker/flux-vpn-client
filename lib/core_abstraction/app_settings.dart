/// Тема оформления — `system` следует настройке ОС, см. [AppSettings].
enum AppThemeMode { system, light, dark }

/// Фон главного экрана подключения (за карточкой Off/Proxy/TUN).
/// `simpleGradient`/`colorBends` — прототипы шейдерных фонов, см.
/// ROADMAP.md, "Фон — шейдерные эффекты".
enum HomeBackground { none, globe, simpleGradient, colorBends }

/// Способ проверки пинга сервера — как в Happ: через локальный
/// прокси-порт xray (реальная задержка "как будет ощущаться"), напрямую по
/// TCP до `address:port` сервера (без ядра), или ICMP-эхо.
enum PingMode { viaProxy, tcp, icmp }

const _defaultPingTestUrl = 'https://www.gstatic.com/generate_204';

/// Настройки приложения — отдельно от [CoreConfig] (серверы/подписки):
/// это предпочтения интерфейса и поведения, не часть профиля, которым можно
/// было бы поделиться. Хранятся в своём файле, см. `app_settings_storage.dart`.
class AppSettings {
  final AppThemeMode themeMode;
  final HomeBackground homeBackground;
  final PingMode pingMode;
  final String pingTestUrl;
  final bool autoGroupSubscriptions;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.homeBackground = HomeBackground.globe,
    this.pingMode = PingMode.viaProxy,
    this.pingTestUrl = _defaultPingTestUrl,
    this.autoGroupSubscriptions = true,
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
    autoGroupSubscriptions: json['autoGroupSubscriptions'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'homeBackground': homeBackground.name,
    'pingMode': pingMode.name,
    'pingTestUrl': pingTestUrl,
    'autoGroupSubscriptions': autoGroupSubscriptions,
  };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    HomeBackground? homeBackground,
    PingMode? pingMode,
    String? pingTestUrl,
    bool? autoGroupSubscriptions,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      homeBackground: homeBackground ?? this.homeBackground,
      pingMode: pingMode ?? this.pingMode,
      pingTestUrl: pingTestUrl ?? this.pingTestUrl,
      autoGroupSubscriptions:
          autoGroupSubscriptions ?? this.autoGroupSubscriptions,
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
