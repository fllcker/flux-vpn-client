import 'dart:async';
import 'dart:io';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../xray/xray_engine_macos.dart';
import 'singbox_engine_macos.dart';

/// macOS-аналог `TunBridgeEngine` (Windows) — тот же паттерн (xray в
/// Proxy-режиме + sing-box поверх него как чистый packet-capture мост, см.
/// комментарий у Windows-класса и `singbox_config_mapper.dart`), но без
/// UAC-подобного релонча всего приложения: на macOS повышаются права только
/// у самого процесса `sing-box` (см. `macos_elevation.dart`), поэтому здесь
/// нет проверки `isRunningElevated()` перед стартом — пользователь просто
/// увидит системный диалог пароля в момент, когда `SingBoxEngineMacOS`
/// реально запускает `sing-box`.
class TunBridgeEngineMacOS implements CoreEngine {
  TunBridgeEngineMacOS({
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

  late final XrayEngineMacOS _xray = XrayEngineMacOS(
    id: '${id}_xray',
    xrayExecutablePath: xrayExecutablePath,
    socksPort: socksPort,
    httpPort: httpPort,
    logLevel: logLevel,
  );
  late final SingBoxEngineMacOS _singBox = SingBoxEngineMacOS(
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
  Future<void> start(
    CoreConfig config, {
    String defaultOutboundTag = 'proxy',
    String routingLabel = 'server-routing',
  }) async {
    _statusController.add(EngineStatus.starting);

    // См. TunBridgeEngine (Windows): падение любой стороны после старта
    // роняет обе — иначе это не "выключено", а тихо оборванный трафик.
    _xraySub = _xray.statusStream.listen((status) {
      if (status == EngineStatus.error && !_stopping) _failAndTeardown();
    });
    _singBoxSub = _singBox.statusStream.listen((status) {
      if (status == EngineStatus.error && !_stopping) _failAndTeardown();
    });

    // См. `TunBridgeEngine` (Windows) — тот же приём и та же причина:
    // внутренний xray тут только труба до VLESS-сервера, реальное доменное
    // решение в TUN-режиме принимает sing-box (сниффинг SNI), у xray на
    // этом пути нет домена, чтобы сравнить со своими `routing.rules`, так
    // что его собственный `defaultOutboundTag` всегда должен быть `'proxy'`,
    // а не значение пресета.
    await _xray.start(
      config,
      manageSystemProxy: false,
      routingLabel: routingLabel,
    );

    final serverHost = _xray.activeServer!.address;
    await _singBox.start(
      socksInPort: socksPort,
      serverHost: serverHost,
      serverIps: await _resolveServerIps(serverHost),
      upstreamDns: upstreamDns,
      logLevel: logLevel,
      routingRules: _xray.activeRoutingRules,
      defaultOutboundTag: defaultOutboundTag,
      routingLabel: routingLabel,
    );

    _statusController.add(EngineStatus.connected);
  }

  /// См. `TunBridgeEngine._resolveServerIps` (Windows) — тот же повод.
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
    await _singBox.stop();
    await _xray.stop();
    _stopping = false;
    _statusController.add(EngineStatus.stopped);
  }

  @override
  Future<EngineStats> currentStats() => _xray.currentStats();
}
