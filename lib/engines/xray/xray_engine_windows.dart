import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/app_paths.dart';
import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import 'child_process_job.dart';
import 'windows_system_proxy.dart';
import 'xray_config_mapper.dart';

/// Windows-реализация [CoreEngine] для xray-core: управляет `xray.exe` как
/// подпроцессом — см. PLAN.md, "Ядро №1: xray-core" → "Стратегия для
/// Windows". Всегда поднимает Proxy-конфиг (SOCKS/HTTP на локальных
/// портах) — раньше умел ещё и TUN-режим напрямую, но актуальный
/// xray-core на Windows физически не настраивает ни IP, ни маршруты на
/// созданном `tun`-адаптере (см. docs/fix_tun/), поэтому TUN теперь
/// собирается отдельно, через sing-box поверх уже поднятого здесь
/// SOCKS-порта — см. `lib/engines/singbox/tun_bridge_engine.dart`. Этот
/// класс используется и напрямую (самостоятельный Proxy-режим), и как
/// внутренний бэкенд [TunBridgeEngine] — конфиг в обоих случаях один и тот
/// же, поэтому [manageSystemProxy] позволяет второму не трогать реестр
/// системного прокси (это по-прежнему только забота самостоятельного
/// Proxy-режима).
class XrayEngineWindows implements CoreEngine {
  XrayEngineWindows({
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

  /// Сервер, к которому подключён текущий (или последний) запуск — выбор
  /// делается тут, внутри [start], из всего дерева [CoreConfig]. Нужен
  /// [TunBridgeEngine]: sing-box'у для обхода тоннеля надо знать адрес именно
  /// того сервера, с которым реально говорит xray (см.
  /// `singbox_config_mapper.dart`), а повторять здешнюю логику выбора листа у
  /// себя — значит однажды разойтись с ней и молча обходить не тот адрес.
  ServerConfig? get activeServer => _activeServer;

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

    final process = await Process.start(xrayExecutablePath, [
      'run',
      '-c',
      configFile.path,
    ]);
    _process = process;
    tieChildProcessLifetimeToApp(process);
    unawaited(_pipeLogs(process));

    unawaited(
      process.exitCode.then((_) {
        // Процесс мог упасть сам по себе (не через stop()) — прокси всё
        // равно нужно снять, иначе пользователь тихо теряет интернет.
        if (_manageSystemProxy) disableWindowsSystemProxy();
        _statusController.add(EngineStatus.stopped);
      }),
    );

    if (_manageSystemProxy) {
      enableWindowsSystemProxy(httpPort: httpPort);
    }
    _statusController.add(EngineStatus.connected);
  }

  @override
  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    if (_manageSystemProxy) disableWindowsSystemProxy();
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

  /// `xray.exe`'s own stdout/stderr (route/adapter errors, dial errors,
  /// ...) was going nowhere — the engine only ever looked at the process
  /// exit code, so a session that "connects" but silently misbehaves left
  /// no trace to diagnose from. Mirror both streams into a log file next
  /// to the generated config so a failed session can be inspected
  /// afterwards.
  Future<void> _pipeLogs(Process process) async {
    final logFile = File('${ensureFluxLogDirectory()}/flux_xray_$id.log');
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
      ServerGroup group => group.children
          .map(_firstLeaf)
          .firstWhere((leaf) => leaf != null, orElse: () => null),
    };
  }
}

/// Путь к `xray.exe`, полученному через `scripts/fetch_xray.ps1` (см.
/// assets/xray/SOURCE.md). Раньше строился от `Directory.current.path` —
/// под `flutter run` это случайно совпадало с корнем проекта, но при
/// запуске собранного .exe напрямую (двойной клик, elevated-перезапуск
/// через ShellExecute) рабочая директория не гарантирована и реально
/// ловилась `ProcessException: system cannot find the file specified`.
/// Берём каталог самого исполняемого файла — он не зависит от того, как и
/// откуда процесс был запущен; `windows/CMakeLists.txt` копирует
/// `assets/xray` рядом с ним при каждой сборке.
String defaultXrayExecutablePath() =>
    '${File(Platform.resolvedExecutable).parent.path}/assets/xray/xray.exe';
