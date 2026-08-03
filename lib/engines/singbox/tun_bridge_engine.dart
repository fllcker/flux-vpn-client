import 'dart:async';
import 'dart:io';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../l10n/strings.dart';
import '../xray/windows_elevation.dart';
import '../xray/xray_engine_windows.dart';
import 'singbox_engine_windows.dart';

/// Реализация TUN-режима на Windows: связка двух процессов под одним
/// [CoreEngine]-фасадом. Причина — см. `singbox_config_mapper.dart` и
/// docs/fix_tun/: xray-core на Windows не умеет сам настроить IP/маршруты
/// на созданном TUN-адаптере, а sing-box умеет (`auto_route`), поэтому TUN
/// собирается как: xray в обычном Proxy-режиме (SOCKS-порт) + sing-box
/// поверх него, который перехватывает пакеты системы и шлёт их в этот SOCKS
/// (кроме трафика самого xray и резолва адреса сервера — их sing-box наоборот
/// обязан вывести мимо тоннеля, иначе xray'ю нужен тоннель, чтобы поднять
/// тоннель; см. `singbox_config_mapper.dart`). Реальный протокол
/// (VLESS/Hysteria2) как всегда ведёт xray.
///
/// `CoreType.singbox` тут — это "движок TUN-режима", а не буквально
/// "sing-box как протокольное ядро": единственный текущий потребитель этого
/// enum-значения, до этого объявленного, но нигде не использовавшегося.
class TunBridgeEngine implements CoreEngine {
  TunBridgeEngine({
    required this.id,
    required this.xrayExecutablePath,
    required this.singBoxExecutablePath,
    this.socksPort = 10808,
    this.httpPort = 10809,
    this.upstreamDns = defaultTunDnsServer,
    this.logLevel = CoreLogLevel.warn,
  });

  @override
  final String id;

  @override
  CoreType get type => CoreType.singbox;

  final String xrayExecutablePath;
  final String singBoxExecutablePath;
  final int socksPort;
  final int httpPort;
  final String upstreamDns;
  final CoreLogLevel logLevel;

  late final XrayEngineWindows _xray = XrayEngineWindows(
    id: '${id}_xray',
    xrayExecutablePath: xrayExecutablePath,
    socksPort: socksPort,
    httpPort: httpPort,
    logLevel: logLevel,
  );
  late final SingBoxEngineWindows _singBox = SingBoxEngineWindows(
    id: '${id}_singbox',
    executablePath: singBoxExecutablePath,
  );

  StreamSubscription<EngineStatus>? _xraySub;
  StreamSubscription<EngineStatus>? _singBoxSub;
  bool _stopping = false;

  final _statusController = StreamController<EngineStatus>.broadcast();
  final _statsController = StreamController<EngineStats>.broadcast();

  @override
  Stream<EngineStatus> get statusStream => _statusController.stream;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  Future<void> start(CoreConfig config, {String defaultOutboundTag = 'proxy'}) async {
    _statusController.add(EngineStatus.starting);

    if (!isRunningElevated()) {
      _statusController.add(EngineStatus.error);
      throw StateError(S.tunRequiresAdminRights);
    }

    // Половина моста без второй — это не "выключено", а тихо оборванный
    // трафик, поэтому падение любой стороны после старта роняет обе.
    _xraySub = _xray.statusStream.listen((status) {
      if (status == EngineStatus.error && !_stopping) _failAndTeardown();
    });
    _singBoxSub = _singBox.statusStream.listen((status) {
      if (status == EngineStatus.error && !_stopping) _failAndTeardown();
    });

    // sing-box's socks-out дозванивается на socksPort сразу при старте —
    // xray должен уже слушать его к этому моменту.
    await _xray.start(
      config,
      manageSystemProxy: false,
      defaultOutboundTag: defaultOutboundTag,
    );

    final serverHost = _xray.activeServer!.address;
    await _singBox.start(
      socksInPort: socksPort,
      serverHost: serverHost,
      serverIps: await _resolveServerIps(serverHost),
      upstreamDns: upstreamDns,
      logLevel: logLevel,
      routingRules: _xray.activeRoutingRules,
      defaultOutboundTag: _xray.activeDefaultOutboundTag,
    );

    _statusController.add(EngineStatus.connected);
  }

  /// Резолвим адрес сервера здесь, между старта xray и старта sing-box, по
  /// одной причине: это последний момент, когда системный DNS ещё работает
  /// как обычно. Как только sing-box поднимет TUN, `auto_route` заберёт
  /// default route, и тот же самый lookup будет уже зависеть от тоннеля,
  /// который мы этими адресами и пытаемся дать поднять.
  ///
  /// Best-effort: пустой список — не ошибка. IP-пиннинг в конфиге sing-box
  /// это лишь страховка поверх правила по `process_name`, поэтому упавший
  /// резолв (или адрес-литерал, которому резолв не нужен) не должен ронять
  /// подключение целиком.
  Future<List<String>> _resolveServerIps(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      return [for (final address in addresses) address.address];
    } on SocketException {
      return const [];
    }
  }

  Future<void> _failAndTeardown() async {
    _statusController.add(EngineStatus.error);
    await stop();
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    _statusController.add(EngineStatus.stopping);
    unawaited(_xraySub?.cancel());
    unawaited(_singBoxSub?.cancel());
    // Обратный порядок запуску: сперва останавливаем перехват пакетов
    // (sing-box), пока SOCKS-порт, в который он их шлёт, ещё жив — так же,
    // как уже сделано в connection_controller.dart для порядка запуска.
    await _singBox.stop();
    await _xray.stop();
    _stopping = false;
    _statusController.add(EngineStatus.stopped);
  }

  @override
  Future<EngineStats> currentStats() => _xray.currentStats();
}
