import 'dart:async';
import 'dart:io';

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
import '../../engines/xray/xray_engine_android.dart';
import '../../engines/xray/xray_engine_windows.dart';
import '../../l10n/strings.dart';
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

  // Каждый вызов connectToServer/disconnect бьёт себе номер и после каждого
  // await сверяется, не обогнал ли его более новый вызов (ROADMAP.md, трек
  // 15 — быстрый повторный клик/переключение из трея во время уже идущего
  // перехода). UI-уровень (`connect_panel.dart`'s `busy`) блокирует обычные
  // клики, но не защищает от программных вызовов — без этой проверки
  // застрявший старый вызов мог после своего `await` перезаписать состояние,
  // выставленное уже более новым.
  int _generation = 0;

  @override
  ConnectionUiState build() {
    ref.onDispose(() => _statusSub?.cancel());
    return const ConnectionIdle();
  }

  Future<void> connectToServer(
    ServerLeaf leaf, {
    ConnectionMode mode = ConnectionMode.proxy,
  }) async {
    final generation = ++_generation;
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
    if (generation != _generation) return;
    _engine = null;

    final settings = ref.read(appSettingsProvider);
    // Android has no Windows-style separate Proxy/TUN mechanism (no system
    // proxy hook outside VpnService, see xray_engine_android.dart) — both
    // modes converge onto the same VpnService-backed engine there,
    // regardless of `mode`. UI still offers the Off/Proxy/TUN selector on
    // every platform (ROADMAP.md, трек 19 — UI convergence is a later step).
    final coreType = Platform.isAndroid
        ? CoreType.xray
        : (mode == ConnectionMode.tun ? CoreType.singbox : CoreType.xray);
    engineManager.registerFactory(coreType, (id) {
      if (Platform.isAndroid) {
        return XrayEngineAndroid(id: id, logLevel: settings.coreLogLevel);
      }
      return switch (mode) {
        ConnectionMode.proxy => XrayEngineWindows(
          id: id,
          xrayExecutablePath: defaultXrayExecutablePath(),
          logLevel: settings.coreLogLevel,
        ),
        ConnectionMode.tun => switch (settings.tunCoreType) {
          TunCoreType.singBox => TunBridgeEngine(
            id: id,
            xrayExecutablePath: defaultXrayExecutablePath(),
            singBoxExecutablePath: defaultSingBoxExecutablePath(),
            upstreamDns: settings.tunDnsServer,
            logLevel: settings.coreLogLevel,
          ),
        },
      };
    });
    if (generation != _generation) return;
    final engine = engineManager.createEngine(coreType, _engineId);
    _engine = engine;

    unawaited(_statusSub?.cancel());
    _statusSub = engine.statusStream.listen((status) {
      if (generation != _generation) return;
      switch (status) {
        case EngineStatus.connected:
          state = ConnectionConnected(
            leafId: leaf.id,
            serverName: leaf.name,
            connectedAt: DateTime.now(),
            mode: mode,
          );
        case EngineStatus.error:
          state = ConnectionError(S.engineFailedWithError);
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
      if (generation == _generation) state = ConnectionError('$e');
    }
  }

  Future<void> disconnect() async {
    final generation = ++_generation;
    state = const ConnectionStopping();
    await _engine?.stop();
    if (generation != _generation) return;
    state = const ConnectionIdle();
  }
}
