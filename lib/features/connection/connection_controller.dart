import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_config_provider.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/effective_routing.dart';
import '../../core_abstraction/engine_manager_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/singbox/singbox_engine_windows.dart';
import '../../engines/singbox/tun_bridge_engine.dart';
import '../../engines/singbox/tun_bridge_engine_macos_ne.dart';
import '../../engines/xray/xray_engine_android.dart';
import '../../engines/xray/xray_engine_macos.dart';
import '../../engines/xray/xray_engine_windows.dart';
import '../../l10n/strings.dart';
import '../servers/flatten_leaves.dart';
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
    // Роутинг разрешается один раз при старте движка (см. комментарий у
    // `connectToServer` про `effectiveRoutingRules`/`effectiveDefaultOutboundTag`)
    // — сам движок не знает о пресетах и не следит за их сменой, поэтому
    // смена активного пресета во время уже установленного соединения молча
    // не подхватилась бы иначе. `forceReconnect: true` в обход no-op-проверки
    // ниже — тут сервер/вариант/режим не меняются, только правила.
    ref.listen(appSettingsProvider, (previous, next) {
      if (previous?.activeRoutingPresetId == next.activeRoutingPresetId) return;
      final current = state;
      if (current is! ConnectionConnected) return;
      ServerLeaf? leaf;
      for (final candidate in flattenAllLeaves(ref.read(coreConfigProvider))) {
        if (candidate.id == current.leafId) {
          leaf = candidate;
          break;
        }
      }
      if (leaf == null) return;
      unawaited(
        connectToServer(leaf, mode: current.mode, forceReconnect: true),
      );
    });
    return const ConnectionIdle();
  }

  Future<void> connectToServer(
    ServerLeaf leaf, {
    ConnectionMode mode = ConnectionMode.proxy,
    bool forceReconnect = false,
  }) async {
    // Клик по уже активному серверу/варианту/режиму (напр. повторный тап по
    // тому же серверу в списке, см. ROADMAP.md) не должен приводить к
    // полному disconnect+reconnect — сверяем не только leafId, но и активный
    // вариант подключения (xhttp/hysteria2/...) и режим (Proxy/TUN): смена
    // любого из них — это осознанный реконнект (см. `server_list_panel.dart`
    // `reconnectToLeafIfActive`, `connect_panel.dart` `_onSelectionChanged`),
    // а вот "тот же сервер, тот же вариант, тот же режим" — no-op.
    // [forceReconnect] обходит эту проверку — используется сменой активного
    // пресета роутинга (см. `build()`), где сервер/вариант/режим не меняются
    // вовсе, но конфиг всё равно нужно перегенерировать и перезапустить.
    final current = state;
    if (!forceReconnect &&
        current is ConnectionConnected &&
        current.leafId == leaf.id &&
        current.variantId == leaf.activeVariant?.id &&
        current.mode == mode) {
      return;
    }

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
        return XrayEngineAndroid(
          id: id,
          logLevel: settings.coreLogLevel,
          geoipUrl: settings.geoipUrl,
          geositeUrl: settings.geositeUrl,
        );
      }
      if (Platform.isMacOS) {
        return switch (mode) {
          ConnectionMode.proxy => XrayEngineMacOS(
            id: id,
            xrayExecutablePath: defaultMacosXrayExecutablePath(),
            logLevel: settings.coreLogLevel,
          ),
          ConnectionMode.tun => switch (settings.tunCoreType) {
            TunCoreType.singBox => TunBridgeEngineMacOSNe(
              id: id,
              upstreamDns: settings.tunDnsServer,
              logLevel: settings.coreLogLevel,
            ),
          },
        };
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
            variantId: leaf.activeVariant?.id,
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

    // Разрешаем эффективные правила роутинга ровно один раз тут, до передачи
    // в движок: активный пресет (`AppSettings.activeRoutingPresetId`)
    // подменяет `leaf.routingRules` для всех серверов сразу, кроме пресета
    // "Роутинг сервера" (null) — см. `effective_routing.dart`. Движки
    // (`XrayEngineWindows` и т.д.) продолжают читать `routingRules` прямо с
    // листа в `CoreConfig`, не зная о пресетах вовсе.
    final coreConfig = ref.read(coreConfigProvider);
    final effectiveLeaf = leaf.withRoutingRules(
      effectiveRoutingRules(
        leaf: leaf,
        activePresetId: settings.activeRoutingPresetId,
        presets: coreConfig.routingPresets,
      ),
    );
    final defaultOutboundTag = effectiveDefaultOutboundTag(
      activePresetId: settings.activeRoutingPresetId,
      presets: coreConfig.routingPresets,
    );
    final routingLabel = effectiveRoutingLabel(
      activePresetId: settings.activeRoutingPresetId,
      presets: coreConfig.routingPresets,
    );
    final config = CoreConfig(standaloneNodes: [effectiveLeaf]);

    try {
      await engine.start(
        config,
        defaultOutboundTag: defaultOutboundTag,
        routingLabel: routingLabel,
      );
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
