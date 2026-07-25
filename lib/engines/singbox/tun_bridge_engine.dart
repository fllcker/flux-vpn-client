import 'dart:async';

import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../xray/windows_elevation.dart';
import '../xray/xray_engine_windows.dart';
import 'singbox_engine_windows.dart';

/// Реализация TUN-режима на Windows: связка двух процессов под одним
/// [CoreEngine]-фасадом. Причина — см. `singbox_config_mapper.dart` и
/// docs/fix_tun/: xray-core на Windows не умеет сам настроить IP/маршруты
/// на созданном TUN-адаптере, а sing-box умеет (`auto_route`), поэтому TUN
/// собирается как: xray в обычном Proxy-режиме (SOCKS-порт) + sing-box
/// поверх него, который только перехватывает пакеты системы и шлёт их в
/// этот SOCKS. Реальный протокол (VLESS/Hysteria2) как всегда ведёт xray.
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
  });

  @override
  final String id;

  @override
  CoreType get type => CoreType.singbox;

  final String xrayExecutablePath;
  final String singBoxExecutablePath;
  final int socksPort;
  final int httpPort;

  late final XrayEngineWindows _xray = XrayEngineWindows(
    id: '${id}_xray',
    xrayExecutablePath: xrayExecutablePath,
    socksPort: socksPort,
    httpPort: httpPort,
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
  Future<void> start(CoreConfig config) async {
    _statusController.add(EngineStatus.starting);

    if (!isRunningElevated()) {
      _statusController.add(EngineStatus.error);
      throw StateError(
        'TUN-режим требует прав администратора — приложение запущено без них',
      );
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
    await _xray.start(config, manageSystemProxy: false);
    await _singBox.start(socksInPort: socksPort);

    _statusController.add(EngineStatus.connected);
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
