import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/ping/ping_cache.dart';
import 'package:flux/features/ping/pick_best_by_latency.dart';

const _germany = ServerLeaf(
  id: 'de',
  name: 'Germany',
  variants: [
    ConnectionVariant(
      id: 'v1',
      label: 'TCP',
      config: VlessConfig(address: 'de.example.com', port: 443, uuid: 'u1'),
    ),
  ],
);
const _poland = ServerLeaf(
  id: 'pl',
  name: 'Poland',
  variants: [
    ConnectionVariant(
      id: 'v2',
      label: 'TCP',
      config: VlessConfig(address: 'pl.example.com', port: 443, uuid: 'u2'),
    ),
  ],
);

void main() {
  test('picks the leaf with the lowest fresh latency', () {
    final now = DateTime.now();
    final cache = {
      'de': PingCacheEntry(latencyMs: 120, measuredAt: now),
      'pl': PingCacheEntry(latencyMs: 40, measuredAt: now),
    };

    expect(pickBestByLatency([_germany, _poland], cache), 'pl');
  });

  test('ignores leaves with no cache entry', () {
    final cache = {'de': PingCacheEntry(latencyMs: 120, measuredAt: DateTime.now())};

    expect(pickBestByLatency([_germany, _poland], cache), 'de');
  });

  test('ignores stale cache entries older than 5 minutes', () {
    final stale = DateTime.now().subtract(const Duration(minutes: 10));
    final cache = {'de': PingCacheEntry(latencyMs: 10, measuredAt: stale)};

    expect(pickBestByLatency([_germany, _poland], cache), isNull);
  });

  test('returns null when the cache is empty', () {
    expect(pickBestByLatency([_germany, _poland], {}), isNull);
  });
}
