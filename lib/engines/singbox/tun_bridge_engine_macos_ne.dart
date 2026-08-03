import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../xray/xray_config_mapper.dart';
import '../xray/xray_engine_macos.dart' show defaultMacosXrayExecutablePath;
import 'geo_ruleset_cache.dart';
import 'singbox_config_mapper.dart';

/// macOS TUN через `NetworkExtension`/`NEPacketTunnelProvider` — правильный
/// долгосрочный дизайн (см. docs/internal/macos/ROADMAP.md), заменяет
/// `TunBridgeEngineMacOS` (osascript-элевация `sing-box`-подпроцесса).
/// Архитектура моста та же: xray говорит с VLESS/Hysteria2-сервером и
/// слушает локальный SOCKS, sing-box (тут — `libbox`, встроенный в System
/// Extension, см. `FluxTunnelExtension/PacketTunnelProvider.swift`) — чистый
/// packet-capture мост перед ним. Разница только в том, кто поднимает TUN и
/// системные маршруты: раньше — сам sing-box через `auto_route` на голом
/// `utun`, требовавший root; теперь — `NEPacketTunnelProvider` через
/// `setTunnelNetworkSettings`, без root и с приоритетом системного VPN (не
/// конфликтует с другими VPN-приложениями, см. инцидент с v2RayTun в
/// ROADMAP.md).
///
/// Мост Dart↔native — тот же паттерн, что `XrayEngineAndroid`
/// (`flux/vpn` MethodChannel + `flux/vpn/status` EventChannel,
/// см. `MainActivity.kt`/`VpnStatusBridge.kt`) — здесь канал регистрирует
/// `NetworkExtensionBridge.swift` в `macos/Runner/`. xray-бинарник и его
/// конфиг передаются расширению через `options` в `startTunnel` — сам
/// процесс `xray` запускает уже `PacketTunnelProvider` (обычный
/// child-процесс System Extension, root не нужен — см. её комментарий).
class TunBridgeEngineMacOSNe implements CoreEngine {
  TunBridgeEngineMacOSNe({
    required this.id,
    this.socksPort = 10808,
    this.httpPort = 10809,
    this.upstreamDns = defaultTunDnsServer,
    this.logLevel = CoreLogLevel.warn,
  });

  static const _channel = MethodChannel('flux/vpn');
  static const _statusChannel = EventChannel('flux/vpn/status');

  @override
  final String id;

  @override
  CoreType get type => CoreType.singbox;

  final int socksPort;
  final int httpPort;
  final String upstreamDns;
  final CoreLogLevel logLevel;

  final _statusController = StreamController<EngineStatus>.broadcast();
  final _statsController = StreamController<EngineStats>.broadcast();
  StreamSubscription<dynamic>? _nativeStatusSub;

  @override
  Stream<EngineStatus> get statusStream => _statusController.stream;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  // `routingLabel` не используется здесь — в отличие от процесс-based
  // движков (`XrayEngineWindows`/`SingBoxEngineWindows` и т.д., см.
  // `routing_debug_header.dart`), у этого моста нет своего файлового лога на
  // Dart-стороне: конфиги уходят в System Extension через `MethodChannel`
  // как есть, логи (если есть) — целиком на нативной/Swift стороне.
  @override
  Future<void> start(
    CoreConfig config, {
    String defaultOutboundTag = 'proxy',
    String routingLabel = 'server-routing',
  }) async {
    _statusController.add(EngineStatus.starting);
    _listenToNativeStatus();

    final leaf = _firstLeafWithConfig(config);
    final server = leaf?.activeVariant?.config;
    if (leaf == null || server == null) {
      _statusController.add(EngineStatus.error);
      throw StateError('CoreConfig has no server to connect to');
    }

    final granted =
        await _channel.invokeMethod<bool>('preparePermission') ?? false;
    if (!granted) {
      _statusController.add(EngineStatus.error);
      throw StateError('System Extension activation was not granted');
    }

    // `defaultOutboundTag` внутреннему xray НЕ передаём (остаётся дефолтным
    // 'proxy') — та же причина, что в `TunBridgeEngine`/`TunBridgeEngineMacOS`
    // (Windows/osascript-мост): здесь xray лишь труба до VLESS-сервера,
    // реальное доменное решение (через тоннель или нет) принимает sing-box
    // (сниффинг SNI внутри `PacketTunnelProvider`), у xray на этом пути нет
    // домена, чтобы сравнить со своими `routing.rules` — если дать ему
    // собственный `defaultOutboundTag`, он молча переигрывает уже принятое
    // sing-box'ом решение для немаршрутизированного (по домену) IP-трафика.
    final xrayConfig = buildXrayConfig(
      server,
      socksPort: socksPort,
      httpPort: httpPort,
      routingRules: leaf.routingRules,
      logLevel: logLevel,
    );

    final serverIps = await _resolveServerIps(server.address);
    final ruleSetPaths = await _resolveRuleSetPaths(leaf.routingRules);
    final singboxConfig = buildSingBoxTunBridgeConfig(
      socksInPort: socksPort,
      serverHost: server.address,
      serverIps: serverIps,
      upstreamDns: upstreamDns,
      logLevel: logLevel,
      routingRules: leaf.routingRules,
      ruleSetPaths: ruleSetPaths,
      defaultOutboundTag: defaultOutboundTag,
    );

    await _channel.invokeMethod('start', {
      'configContent': jsonEncode(singboxConfig),
      'xrayExecutablePath': defaultMacosXrayExecutablePath(),
      'xrayConfigContent': jsonEncode(xrayConfig),
    });

    _statusController.add(EngineStatus.connected);
  }

  @override
  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    await _channel.invokeMethod('stop');
    unawaited(_nativeStatusSub?.cancel());
    _nativeStatusSub = null;
    _statusController.add(EngineStatus.stopped);
  }

  /// См. `XrayEngineAndroid._listenToNativeStatus` — та же логика: `start()`
  /// оптимистично помечает `connected` сразу после того, как MethodChannel
  /// вызов принят, а сюда потом приходят асинхронные события (сбой уже
  /// после старта, отключение через системный UI и т.п.).
  void _listenToNativeStatus() {
    unawaited(_nativeStatusSub?.cancel());
    _nativeStatusSub = _statusChannel.receiveBroadcastStream().listen((event) {
      final map = event as Map<dynamic, dynamic>;
      switch (map['event']) {
        case 'started':
          break;
        case 'stopped':
          _statusController.add(EngineStatus.stopped);
        case 'error':
          _statusController.add(EngineStatus.error);
      }
    });
  }

  /// См. `TunBridgeEngineMacOS._resolveServerIps` — тот же повод
  /// (route_exclude_address на реальном IP сервера).
  Future<List<String>> _resolveServerIps(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      return [for (final address in addresses) address.address];
    } on SocketException {
      return const [];
    }
  }

  /// См. `SingBoxEngineMacOS._resolveRuleSetPaths` — тот же приём.
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

  @override
  Future<EngineStats> currentStats() async {
    return const EngineStats(uploadBytes: 0, downloadBytes: 0);
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
