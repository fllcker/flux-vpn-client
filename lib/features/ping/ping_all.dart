import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/proxy_node.dart';
import 'ping_cache.dart';
import 'ping_service.dart';

/// Пингует один сервер и, при успехе, сохраняет результат в кэш — общая
/// логика для кнопки "Пинг" на строке сервера, "Пинг всех" и автопинга при
/// запуске (см. ROADMAP.md, трек 4).
Future<void> pingLeaf(WidgetRef ref, ServerLeaf leaf) async {
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
