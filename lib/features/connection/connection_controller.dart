import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/engine_manager_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/singbox/singbox_engine_windows.dart';
import '../../engines/singbox/tun_bridge_engine.dart';
import '../../engines/xray/xray_engine_windows.dart';
import 'connection_state.dart';

final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionUiState>(
  ConnectionController.new,
);

/// Первый сквозной сценарий из PLAN.md ("Ближайшие шаги", п.4): выбрать
/// сервер → подключиться через движок конкретного режима → увидеть статус.
/// Один активный движок с фиксированным id — переключение между несколькими
/// одновременными подключениями ещё не реализовано.
///
/// Proxy-режим — [XrayEngineWindows] напрямую. TUN-режим — [TunBridgeEngine]
/// (xray в Proxy-режиме + sing-box поверх как packet-capture мост, см.
/// `lib/engines/singbox/tun_bridge_engine.dart` — xray-core на Windows сам
/// не умеет настроить IP/маршруты на TUN-адаптере). Какая конкретно
/// TUN-реализация используется — решает `AppSettings.tunCoreType`;
/// сейчас единственный вариант, но ветвление сделано явным, чтобы второй
/// вариант добавлялся без переписывания этого контроллера.
class ConnectionController extends Notifier<ConnectionUiState> {
  static const _engineId = 'primary';

  StreamSubscription<EngineStatus>? _statusSub;
  CoreEngine? _engine;

  @override
  ConnectionUiState build() {
    ref.onDispose(() => _statusSub?.cancel());
    return const ConnectionIdle();
  }

  Future<void> connectToServer(
    ServerLeaf leaf, {
    ConnectionMode mode = ConnectionMode.proxy,
  }) async {
    state = const ConnectionConnecting();

    // Переключение сервера/режима (напр. TUN → Proxy) раньше просто
    // перезаписывало _engine новым инстансом — старый процесс xray.exe
    // (и, в TUN-режиме, wintun-адаптер с уже установленными маршрутами)
    // никто не останавливал, он продолжал жить в фоне. Второй процесс
    // конфликтовал с первым (общий путь временного конфига/лога) и падал
    // почти сразу, из-за чего UI откатывался в Off, а осиротевший TUN-адаптер
    // оставался висеть в системе. Останавливаем предыдущий движок перед
    // стартом нового — как и в disconnect().
    final engineManager = ref.read(engineManagerProvider);
    await engineManager.removeEngine(_engineId);
    _engine = null;

    final tunCoreType = ref.read(appSettingsProvider).tunCoreType;
    final coreType = mode == ConnectionMode.tun ? CoreType.singbox : CoreType.xray;
    engineManager.registerFactory(coreType, (id) => switch (mode) {
      ConnectionMode.proxy => XrayEngineWindows(
        id: id,
        xrayExecutablePath: defaultXrayExecutablePath(),
      ),
      ConnectionMode.tun => switch (tunCoreType) {
        TunCoreType.singBox => TunBridgeEngine(
          id: id,
          xrayExecutablePath: defaultXrayExecutablePath(),
          singBoxExecutablePath: defaultSingBoxExecutablePath(),
        ),
      },
    });
    final engine = engineManager.createEngine(coreType, _engineId);
    _engine = engine;

    unawaited(_statusSub?.cancel());
    _statusSub = engine.statusStream.listen((status) {
      switch (status) {
        case EngineStatus.connected:
          state = ConnectionConnected(
            serverName: leaf.name,
            connectedAt: DateTime.now(),
            mode: mode,
          );
        case EngineStatus.error:
          state = const ConnectionError('Ядро завершилось с ошибкой');
        case EngineStatus.stopped:
          state = const ConnectionIdle();
        case EngineStatus.starting:
        case EngineStatus.stopping:
          break;
      }
    });

    final config = CoreConfig(standaloneNodes: [leaf]);

    try {
      await engine.start(config);
    } catch (e) {
      state = ConnectionError('$e');
    }
  }

  Future<void> disconnect() async {
    state = const ConnectionStopping();
    await _engine?.stop();
    state = const ConnectionIdle();
  }
}
