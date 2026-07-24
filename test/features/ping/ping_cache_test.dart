import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/ping/ping_cache.dart';

void main() {
  test('PingCacheEntry round-trips through JSON', () {
    final entry = PingCacheEntry(
      latencyMs: 42,
      measuredAt: DateTime.utc(2026, 1, 1, 12),
    );

    final restored = PingCacheEntry.fromJson(entry.toJson());

    expect(restored.latencyMs, 42);
    expect(restored.measuredAt, DateTime.utc(2026, 1, 1, 12));
  });
}
