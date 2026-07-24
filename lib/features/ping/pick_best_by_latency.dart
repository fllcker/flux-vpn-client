import '../../core_abstraction/proxy_node.dart';
import 'ping_cache.dart';

/// Данные пинга старше этого возраста считаются устаревшими для целей
/// авто-выбора — сервер мог давно поменять маршрут/нагрузку.
const _maxPingAge = Duration(minutes: 5);

/// Выбирает id [ServerLeaf] с наименьшей задержкой среди [leaves] по данным
/// [pingCache] — чистая функция, не завязанная на UI-событие "нажал Авто",
/// чтобы её же в будущем можно было вызывать по таймеру/при детекте обрыва
/// для live failover, не переписывая саму логику выбора (см. ROADMAP.md,
/// трек 5). Возвращает `null`, если ни у одного листа нет свежих данных
/// пинга — вызывающий код должен сам выбрать fallback (первый по списку) и
/// запустить фоновый пинг, чтобы данные появились к следующему разу.
String? pickBestByLatency(
  List<ServerLeaf> leaves,
  Map<String, PingCacheEntry> pingCache,
) {
  final now = DateTime.now();
  ServerLeaf? best;
  int? bestLatency;

  for (final leaf in leaves) {
    final entry = pingCache[leaf.id];
    if (entry == null) continue;
    if (now.difference(entry.measuredAt) > _maxPingAge) continue;
    if (bestLatency == null || entry.latencyMs < bestLatency) {
      best = leaf;
      bestLatency = entry.latencyMs;
    }
  }

  return best?.id;
}
