import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/app_paths.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../xray/macos_elevation.dart';
import 'geo_ruleset_cache.dart';
import 'singbox_config_mapper.dart';

/// macOS-обёртка над процессом `sing-box`, используемая изнутри
/// `TunBridgeEngineMacOS` — конфиг (`buildSingBoxTunBridgeConfig`) тот же
/// самый, что и на Windows (см. `singbox_config_mapper.dart`, там уже
/// платформенно-нейтральный `tun`/`auto_route` sing-box-инбаунд, разница
/// только в обвязке процесса). Разница со `SingBoxEngineWindows`: подъём
/// `utun`-интерфейса требует root, которого у обычного процесса на macOS
/// нет — поэтому сам процесс стартует через `startElevatedMacos`
/// (`osascript ... with administrator privileges`), а не напрямую
/// [Process.start], см. предупреждение про `kill()` в `macos_elevation.dart`.
class SingBoxEngineMacOS {
  SingBoxEngineMacOS({required this.id, required this.executablePath});

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
    );
    final configFile = await File(
      '${ensureFluxLogDirectory()}/flux_singbox_$id.json',
    ).writeAsString(jsonEncode(config));
    _configFile = configFile;

    final process = await startElevatedMacos(executablePath, [
      'run',
      '-c',
      configFile.path,
    ]);
    _process = process;
    unawaited(_pipeLogs(process));

    unawaited(
      process.exitCode.then((_) {
        _statusController.add(EngineStatus.stopped);
      }),
    );

    _statusController.add(EngineStatus.connected);
  }

  /// См. `SingBoxEngineWindows._resolveRuleSetPaths` — тот же приём.
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

  /// См. `SingBoxEngineWindows._pipeLogs`.
  Future<void> _pipeLogs(Process process) async {
    final logFile = File('${ensureFluxLogDirectory()}/flux_singbox_$id.log');
    final sink = logFile.openWrite(mode: FileMode.write);
    try {
      await Future.wait([
        process.stdout
            .transform(const SystemEncoding().decoder)
            .forEach(sink.write),
        process.stderr
            .transform(const SystemEncoding().decoder)
            .forEach(sink.write),
      ]);
    } finally {
      await sink.close();
    }
  }
}

/// Путь к `sing-box`, полученному через `scripts/fetch_sing_box_macos.sh`
/// (см. `defaultMacosXrayExecutablePath` в `xray_engine_macos.dart` для
/// объяснения расположения `Contents/Resources/` относительно
/// `Platform.resolvedExecutable`).
String defaultMacosSingBoxExecutablePath() =>
    '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/sing-box/sing-box';
