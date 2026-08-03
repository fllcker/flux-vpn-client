import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/app_paths.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../xray/child_process_job.dart';
import 'geo_ruleset_cache.dart';
import 'singbox_config_mapper.dart';

/// Обёртка над процессом `sing-box.exe`, используемая только изнутри
/// [TunBridgeEngine] — в отличие от [CoreEngine], этому классу не нужен
/// [CoreConfig]: из всего профиля sing-box'у нужен локальный SOCKS-порт xray
/// плюс адрес сервера, и то не чтобы к нему подключаться, а наоборот — чтобы
/// исключить его из тоннеля (см. `singbox_config_mapper.dart`). Поэтому общий
/// интерфейс движка он не реализует.
class SingBoxEngineWindows {
  SingBoxEngineWindows({required this.id, required this.executablePath});

  final String id;
  final String executablePath;

  Process? _process;
  File? _configFile;

  final _statusController = StreamController<EngineStatus>.broadcast();
  Stream<EngineStatus> get statusStream => _statusController.stream;

  Future<void> start({
    required int socksInPort,
    required String serverHost,
    List<String> serverIps = const [],
    String upstreamDns = defaultTunDnsServer,
    CoreLogLevel logLevel = CoreLogLevel.warn,
    List<RoutingRule> routingRules = const [],
    String defaultOutboundTag = 'proxy',
  }) async {
    _statusController.add(EngineStatus.starting);

    final ruleSetPaths = await _resolveRuleSetPaths(routingRules);

    final config = buildSingBoxTunBridgeConfig(
      socksInPort: socksInPort,
      serverHost: serverHost,
      serverIps: serverIps,
      upstreamDns: upstreamDns,
      logLevel: logLevel,
      routingRules: routingRules,
      ruleSetPaths: ruleSetPaths,
      defaultOutboundTag: defaultOutboundTag,
    );
    final configFile = await File(
      '${ensureFluxLogDirectory()}/flux_singbox_$id.json',
    ).writeAsString(jsonEncode(config));
    _configFile = configFile;

    final process = await Process.start(executablePath, [
      'run',
      '-c',
      configFile.path,
    ]);
    _process = process;
    tieChildProcessLifetimeToApp(process);
    unawaited(_pipeLogs(process));

    unawaited(
      process.exitCode.then((_) {
        _statusController.add(EngineStatus.stopped);
      }),
    );

    _statusController.add(EngineStatus.connected);
  }

  /// Резолвит geosite/geoip-теги, на которые ссылаются [routingRules]
  /// (`geoRuleSetReferences`), в пути уже сконвертированных JSON rule-set'ов
  /// (`geo_ruleset_cache.dart`, ROADMAP.md трек 21) — заранее, до вызова
  /// [buildSingBoxTunBridgeConfig], т.к. сама конвертация асинхронная
  /// (читает `.dat` с диска), а мапер остаётся чистой синхронной функцией.
  Future<Map<String, String>> _resolveRuleSetPaths(
    List<RoutingRule> routingRules,
  ) async {
    final paths = <String, String>{};
    for (final tag in geoRuleSetReferences(routingRules)) {
      final category = tag.substring(tag.indexOf('-') + 1);
      paths[tag] = tag.startsWith('geosite-')
          ? await geositeRuleSetPath(category)
          : await geoipRuleSetPath(category);
    }
    return paths;
  }

  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    _process?.kill();
    await _process?.exitCode;
    _process = null;
    await _configFile?.delete();
    _configFile = null;
    _statusController.add(EngineStatus.stopped);
  }

  /// См. аналогичный комментарий в `XrayEngineWindows._pipeLogs` — без этого
  /// ошибки поднятия TUN-адаптера (недостающие права, занятое имя интерфейса,
  /// конфликт с существующим wintun-адаптером) некуда посмотреть постфактум.
  Future<void> _pipeLogs(Process process) async {
    final logFile = File('${ensureFluxLogDirectory()}/flux_singbox_$id.log');
    final sink = logFile.openWrite(mode: FileMode.write);
    try {
      await Future.wait([
        process.stdout.transform(const SystemEncoding().decoder).forEach(sink.write),
        process.stderr.transform(const SystemEncoding().decoder).forEach(sink.write),
      ]);
    } finally {
      await sink.close();
    }
  }
}

/// Путь к `sing-box.exe`, полученному через `scripts/fetch_sing_box.ps1`
/// (см. assets/sing-box/SOURCE.md) — та же логика, что у
/// `defaultXrayExecutablePath()`: от каталога исполняемого файла, а не от
/// текущей рабочей директории, см. её комментарий для полного обоснования.
String defaultSingBoxExecutablePath() =>
    '${File(Platform.resolvedExecutable).parent.path}/assets/sing-box/sing-box.exe';
