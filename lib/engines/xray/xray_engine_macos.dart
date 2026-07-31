import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/app_paths.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import 'child_process_lifecycle_macos.dart';
import 'macos_system_proxy.dart';
import 'xray_config_mapper.dart';

/// macOS-реализация [CoreEngine] для xray-core — тот же subprocess-подход,
/// что и `XrayEngineWindows`, с системным прокси через `networksetup`
/// вместо реестра (см. `macos_system_proxy.dart`). Не требует никаких
/// entitlements — единственный путь, доступный на macOS до появления
/// Developer-аккаунта (см. PLAN.md, "Системная интеграция VPN на macOS").
class XrayEngineMacOS implements CoreEngine {
  XrayEngineMacOS({
    required this.id,
    required this.xrayExecutablePath,
    this.socksPort = 10808,
    this.httpPort = 10809,
    this.logLevel = CoreLogLevel.warn,
  });

  @override
  final String id;

  @override
  CoreType get type => CoreType.xray;

  final String xrayExecutablePath;
  final int socksPort;
  final int httpPort;
  final CoreLogLevel logLevel;

  Process? _process;
  File? _configFile;
  bool _manageSystemProxy = true;
  ServerConfig? _activeServer;

  /// См. `XrayEngineWindows.activeServer` — тот же повод: нужен
  /// [TunBridgeEngine], чтобы sing-box обошёл тоннелем именно тот сервер, с
  /// которым говорит этот xray, без дублирования логики выбора листа.
  ServerConfig? get activeServer => _activeServer;

  List<RoutingRule> _activeRoutingRules = const [];
  List<RoutingRule> get activeRoutingRules => _activeRoutingRules;

  final _statusController = StreamController<EngineStatus>.broadcast();
  final _statsController = StreamController<EngineStats>.broadcast();

  @override
  Stream<EngineStatus> get statusStream => _statusController.stream;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  Future<void> start(CoreConfig config, {bool manageSystemProxy = true}) async {
    _statusController.add(EngineStatus.starting);
    _manageSystemProxy = manageSystemProxy;

    final leaf = _firstLeafWithConfig(config);
    final server = leaf?.activeVariant?.config;
    if (leaf == null || server == null) {
      _statusController.add(EngineStatus.error);
      throw StateError('CoreConfig has no server to connect to');
    }

    _activeServer = server;
    _activeRoutingRules = leaf.routingRules;

    final xrayConfig = buildXrayConfig(
      server,
      socksPort: socksPort,
      httpPort: httpPort,
      routingRules: leaf.routingRules,
      logLevel: logLevel,
    );

    final configFile = await File(
      '${ensureFluxLogDirectory()}/flux_xray_$id.json',
    ).writeAsString(jsonEncode(xrayConfig));
    _configFile = configFile;

    final process = await Process.start(
      xrayExecutablePath,
      ['run', '-c', configFile.path],
      environment: {'XRAY_LOCATION_ASSET': ensureFluxGeoDirectory()},
    );
    _process = process;
    tieChildProcessLifetimeToApp(process);
    unawaited(_pipeLogs(process));

    unawaited(
      process.exitCode.then((_) async {
        // См. XrayEngineWindows: процесс мог упасть сам, прокси всё равно
        // надо снять.
        if (_manageSystemProxy) await disableMacosSystemProxy();
        _statusController.add(EngineStatus.stopped);
      }),
    );

    if (_manageSystemProxy) {
      await enableMacosSystemProxy(httpPort: httpPort);
    }
    _statusController.add(EngineStatus.connected);
  }

  @override
  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    if (_manageSystemProxy) await disableMacosSystemProxy();
    _process?.kill();
    await _process?.exitCode;
    _process = null;
    await _configFile?.delete();
    _configFile = null;
    _statusController.add(EngineStatus.stopped);
  }

  @override
  Future<EngineStats> currentStats() async {
    return const EngineStats(uploadBytes: 0, downloadBytes: 0);
  }

  /// См. `XrayEngineWindows._pipeLogs`.
  Future<void> _pipeLogs(Process process) async {
    final logFile = File('${ensureFluxLogDirectory()}/flux_xray_$id.log');
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

  ServerLeaf? _firstLeafWithConfig(CoreConfig config) {
    final roots = [
      ...config.standaloneNodes,
      ...config.subscriptions.map((s) => s.root),
    ];
    for (final root in roots) {
      final leaf = _firstLeaf(root);
      if (leaf?.activeVariant?.config != null) return leaf;
    }
    return null;
  }

  ServerLeaf? _firstLeaf(ProxyNode node) {
    return switch (node) {
      ServerLeaf leaf => leaf,
      AutoSelectMarker() => null,
      ServerGroup group =>
        group.children
            .map(_firstLeaf)
            .firstWhere((leaf) => leaf != null, orElse: () => null),
    };
  }
}

/// Путь к `xray`, который на macOS кладётся в `Contents/Resources/xray/`
/// бандла приложения (см. `scripts/fetch_xray_macos.sh`) — тот же приём,
/// что и `defaultXrayExecutablePath()` на Windows: от каталога исполняемого
/// файла, а не от текущей рабочей директории. На macOS исполняемый файл
/// живёт в `Contents/MacOS/`, поэтому ресурсы на уровень выше и в
/// `Resources/`, а не рядом с ним, как на Windows.
String defaultMacosXrayExecutablePath() =>
    '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/xray/xray';
