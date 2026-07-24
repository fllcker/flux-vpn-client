import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Результат последнего замера пинга одного сервера/варианта.
class PingCacheEntry {
  final int latencyMs;
  final DateTime measuredAt;

  const PingCacheEntry({required this.latencyMs, required this.measuredAt});

  factory PingCacheEntry.fromJson(Map<String, dynamic> json) =>
      PingCacheEntry(
        latencyMs: json['latencyMs'] as int,
        measuredAt: DateTime.parse(json['measuredAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'latencyMs': latencyMs,
    'measuredAt': measuredAt.toIso8601String(),
  };
}

/// Отдельный лёгкий файл-кэш `%AppData%\flux\ping_cache.json` (по аналогии с
/// `app_settings_storage.dart`) — ключ - id листа. Намеренно не часть
/// Magic JSON-профиля (`profile_storage.dart`): это часто меняющаяся
/// телеметрия, не история/схема профиля, незачем гонять её через
/// `schemaVersion`-миграции. См. ROADMAP.md, трек 4.
class PingCacheStorage {
  const PingCacheStorage();

  File _file() {
    final appData = Platform.environment['APPDATA'];
    final dir = appData != null
        ? '$appData\\flux'
        : '${Directory.systemTemp.path}\\flux';
    return File('$dir\\ping_cache.json');
  }

  Map<String, PingCacheEntry> load() {
    final file = _file();
    if (!file.existsSync()) return {};
    try {
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return json.map(
        (id, entry) =>
            MapEntry(id, PingCacheEntry.fromJson(entry as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  void save(Map<String, PingCacheEntry> cache) {
    final file = _file();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode(cache.map((id, entry) => MapEntry(id, entry.toJson()))),
    );
  }
}

const pingCacheStorage = PingCacheStorage();

final pingCacheProvider =
    NotifierProvider<PingCacheController, Map<String, PingCacheEntry>>(
      PingCacheController.new,
    );

class PingCacheController extends Notifier<Map<String, PingCacheEntry>> {
  @override
  Map<String, PingCacheEntry> build() => pingCacheStorage.load();

  void setResult(String id, int latencyMs) {
    state = {
      ...state,
      id: PingCacheEntry(latencyMs: latencyMs, measuredAt: DateTime.now()),
    };
    pingCacheStorage.save(state);
  }
}

/// Id серверов, для которых прямо сейчас выполняется замер — чисто
/// UI-состояние (спиннер на строке), в файл не сохраняется.
final pingingLeafIdsProvider = NotifierProvider<PingingLeafIdsController, Set<String>>(
  PingingLeafIdsController.new,
);

class PingingLeafIdsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void start(String id) => state = {...state, id};

  void finish(String id) => state = {...state}..remove(id);
}
