import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/connection_session.dart';
import '../../core_abstraction/proxy_node.dart';
import '../connection/connection_controller.dart';
import '../connection/connection_state.dart';
import 'ping_cache.dart';
import 'ping_service.dart';

/// Пинг во время активного TUN мешает соединению — режим `viaProxy` поднимает
/// свой временный xray-процесс, который конкурирует за сетевые ресурсы с уже
/// работающим TUN-мостом (xray+sing-box, см. `tun_bridge_engine.dart`); TCP/
/// ICMP-пинг тоже не запускаем в это время — не ради самого пинга, а чтобы
/// не создавать у пользователя впечатление, что в TUN-режиме измерение вообще
/// уместно (см. ROADMAP.md, трек 11).
bool isTunActive(WidgetRef ref) {
  final state = ref.read(connectionControllerProvider);
  return state is ConnectionConnected && state.mode == ConnectionMode.tun;
}

/// Пингует один сервер и, при успехе, сохраняет результат в кэш — общая
/// логика для кнопки "Пинг" на строке сервера, "Пинг всех" и автопинга при
/// запуске (см. ROADMAP.md, трек 4). Тихий no-op при активном TUN — вызывающая
/// UI-сторона (`server_row.dart`, `server_list_panel.dart`) сама показывает
/// тост при явном клике, здесь только защита от самого запуска.
Future<void> pingLeaf(WidgetRef ref, ServerLeaf leaf) async {
  if (isTunActive(ref)) return;
  final config = leaf.activeVariant?.config;
  if (config == null) return;

  final settings = ref.read(appSettingsProvider);
  ref.read(pingingLeafIdsProvider.notifier).start(leaf.id);
  final latency = await pingService.ping(
    config,
    mode: settings.pingMode,
    pingTestUrl: settings.pingTestUrl,
  );
  ref.read(pingingLeafIdsProvider.notifier).finish(leaf.id);
  if (latency != null) {
    ref.read(pingCacheProvider.notifier).setResult(leaf.id, latency);
  }
}

/// Пингует список серверов последовательно — параллельный запуск N
/// временных xray-процессов разом (один на сервер, см. `ping_service.dart`)
/// неоправданно грузит систему при большом списке серверов.
Future<void> pingAllLeaves(WidgetRef ref, List<ServerLeaf> leaves) async {
  for (final leaf in leaves) {
    await pingLeaf(ref, leaf);
  }
}
