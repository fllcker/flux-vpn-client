import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/engine_manager_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../engines/xray/xray_engine_windows.dart';
import '../servers/vless_link_parser.dart';
import 'connection_state.dart';

final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionUiState>(
  ConnectionController.new,
);

/// Первый сквозной сценарий из PLAN.md ("Ближайшие шаги", п.4): вставить
/// vless:// ссылку → распарсить → подключиться через XrayEngineWindows →
/// увидеть статус. Один активный движок с фиксированным id — выбор
/// сервера/групп ещё не реализован.
class ConnectionController extends Notifier<ConnectionUiState> {
  static const _engineId = 'primary';

  StreamSubscription<EngineStatus>? _statusSub;
  XrayEngineWindows? _engine;

  @override
  ConnectionUiState build() {
    ref.onDispose(() => _statusSub?.cancel());
    return const ConnectionIdle();
  }

  Future<void> connect(String link) async {
    final ParsedVlessLink parsed;
    try {
      parsed = parseVlessLink(link);
    } on VlessLinkFormatException catch (e) {
      state = ConnectionError(e.message);
      return;
    }

    state = const ConnectionConnecting();

    final engineManager = ref.read(engineManagerProvider);
    engineManager.registerFactory(
      CoreType.xray,
      (id) => XrayEngineWindows(
        id: id,
        xrayExecutablePath: defaultXrayExecutablePath(),
      ),
    );
    final engine =
        engineManager.createEngine(CoreType.xray, _engineId) as XrayEngineWindows;
    _engine = engine;

    unawaited(_statusSub?.cancel());
    _statusSub = engine.statusStream.listen((status) {
      switch (status) {
        case EngineStatus.connected:
          state = ConnectionConnected(serverName: parsed.name);
        case EngineStatus.error:
          state = const ConnectionError('xray-core завершился с ошибкой');
        case EngineStatus.stopped:
          state = const ConnectionIdle();
        case EngineStatus.starting:
        case EngineStatus.stopping:
          break;
      }
    });

    final config = CoreConfig(
      schemaVersion: 1,
      standaloneNodes: [
        ServerLeaf(
          id: 'link',
          name: parsed.name,
          variants: [
            ConnectionVariant(
              id: 'default',
              label: parsed.name,
              config: parsed.config,
            ),
          ],
        ),
      ],
    );

    try {
      await engine.start(config);
    } catch (e) {
      state = ConnectionError('$e');
    }
  }

  Future<void> disconnect() async {
    await _engine?.stop();
    state = const ConnectionIdle();
  }
}
