import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import 'xray_config_mapper.dart';

/// Windows-реализация [CoreEngine] для xray-core: управляет `xray.exe` как
/// подпроцессом — см. PLAN.md, "Ядро №1: xray-core" → "Стратегия для
/// Windows". Реализован только Proxy-режим (Вариант B: локальный
/// SOCKS/HTTP на localhost); TUN-режим (Вариант A) — следующая задача.
class XrayEngineWindows implements CoreEngine {
  XrayEngineWindows({
    required this.id,
    required this.xrayExecutablePath,
    this.socksPort = 10808,
    this.httpPort = 10809,
  });

  @override
  final String id;

  @override
  CoreType get type => CoreType.xray;

  final String xrayExecutablePath;
  final int socksPort;
  final int httpPort;

  Process? _process;
  File? _configFile;

  final _statusController = StreamController<EngineStatus>.broadcast();
  final _statsController = StreamController<EngineStats>.broadcast();

  @override
  Stream<EngineStatus> get statusStream => _statusController.stream;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  Future<void> start(CoreConfig config) async {
    _statusController.add(EngineStatus.starting);

    final server = _firstVlessServer(config);
    if (server == null) {
      _statusController.add(EngineStatus.error);
      throw StateError('CoreConfig has no VLESS server to connect to');
    }

    final xrayConfig = buildXrayConfig(
      server,
      socksPort: socksPort,
      httpPort: httpPort,
    );

    final configFile = await File(
      '${Directory.systemTemp.path}/vpn_client_xray_$id.json',
    ).writeAsString(jsonEncode(xrayConfig));
    _configFile = configFile;

    final process = await Process.start(xrayExecutablePath, [
      'run',
      '-c',
      configFile.path,
    ]);
    _process = process;

    unawaited(
      process.exitCode.then((_) => _statusController.add(EngineStatus.stopped)),
    );

    _statusController.add(EngineStatus.connected);
  }

  @override
  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    _process?.kill();
    await _process?.exitCode;
    _process = null;
    await _configFile?.delete();
    _configFile = null;
    _statusController.add(EngineStatus.stopped);
  }

  @override
  Future<EngineStats> currentStats() async {
    // Stats API xray-core (gRPC/HTTP) пока не подключён — см. "Открытые
    // вопросы" в PLAN.md.
    return const EngineStats(uploadBytes: 0, downloadBytes: 0);
  }

  VlessConfig? _firstVlessServer(CoreConfig config) {
    final roots = [
      ...config.standaloneNodes,
      ...config.subscriptions.map((s) => s.root),
    ];
    for (final root in roots) {
      final leaf = _firstLeaf(root);
      final variant = leaf == null ? null : _activeVariant(leaf);
      if (variant?.config case final VlessConfig vless) {
        return vless;
      }
    }
    return null;
  }

  ServerLeaf? _firstLeaf(ProxyNode node) {
    return switch (node) {
      ServerLeaf leaf => leaf,
      ServerGroup group => group.children
          .map(_firstLeaf)
          .firstWhere((leaf) => leaf != null, orElse: () => null),
    };
  }

  ConnectionVariant? _activeVariant(ServerLeaf leaf) {
    if (leaf.variants.isEmpty) return null;
    final selection = leaf.selection;
    if (selection is ManualVariantSelection) {
      return leaf.variants.firstWhere(
        (v) => v.id == selection.variantId,
        orElse: () => leaf.variants.first,
      );
    }
    return leaf.variants.first;
  }
}
