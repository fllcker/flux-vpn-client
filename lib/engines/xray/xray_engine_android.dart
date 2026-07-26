import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/core_config.dart';
import '../../core_abstraction/core_engine.dart';
import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import '../../l10n/strings.dart';
import 'xray_config_mapper.dart';

/// Android-реализация [CoreEngine] для xray-core — см. `FluxVpnService.kt`
/// (`android/app/src/main/kotlin/rip/freeinternet/flux/`) и ROADMAP.md,
/// трек 19. В отличие от Windows, здесь только один режим по факту: TUN
/// через `VpnService` (xray-core сам умеет TUN на Android, отдельного
/// sing-box-моста не нужно) — Proxy-режим на Android пока не реализован
/// (нет системного эквивалента `windows_system_proxy.dart`, см. план).
/// Вся связь с нативной стороной — один `MethodChannel`, объявленный в
/// `MainActivity.kt`.
class XrayEngineAndroid implements CoreEngine {
  XrayEngineAndroid({required this.id, this.logLevel = CoreLogLevel.warn});

  static const _channel = MethodChannel('flux/vpn');

  @override
  final String id;

  @override
  CoreType get type => CoreType.xray;

  final CoreLogLevel logLevel;

  final _statusController = StreamController<EngineStatus>.broadcast();
  final _statsController = StreamController<EngineStats>.broadcast();

  @override
  Stream<EngineStatus> get statusStream => _statusController.stream;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  Future<void> start(CoreConfig config) async {
    _statusController.add(EngineStatus.starting);

    final leaf = _firstLeafWithConfig(config);
    final server = leaf?.activeVariant?.config;
    if (leaf == null || server == null) {
      _statusController.add(EngineStatus.error);
      throw StateError('CoreConfig has no server to connect to');
    }

    final granted = await _channel.invokeMethod<bool>('preparePermission') ?? false;
    if (!granted) {
      _statusController.add(EngineStatus.error);
      throw StateError(S.vpnPermissionDenied);
    }

    // Тот же приём, что и в tun_bridge_engine.dart на Windows: резолвим
    // адрес сервера до того, как fd уйдёт в xray-core и заберёт себе
    // системный DNS — RouteExclusion в FluxVpnService.kt умеет только
    // IPv4-литерал, не хостнейм.
    final serverIp = await _resolveServerIp(server.address);
    if (serverIp == null) {
      _statusController.add(EngineStatus.error);
      throw StateError('Could not resolve ${server.address}');
    }

    // Мало просто исключить IP сервера из маршрутов TUN — если в конфиге
    // xray-core оставить исходный хостнейм, само ядро при коннекте резолвит
    // его заново (уже своим DNS-запросом), который снова уйдёт в тот же
    // ещё не поднятый туннель — тот самый deadlock "нужен тоннель, чтобы
    // поднять тоннель", от которого на Windows защищаются в
    // tun_bridge_engine.dart. Подставляем уже резолвленный IP как адрес
    // подключения, а SNI/serverName фиксируем на исходном хостнейме явно
    // (иначе xray возьмёт SNI из адреса — станет IP вместо домена, и
    // TLS/Reality-хендшейк не пройдёт).
    final pinnedServer = _pinToResolvedIp(server, serverIp);

    final xrayConfig = buildXrayTunConfig(
      pinnedServer,
      routingRules: leaf.routingRules,
      logLevel: logLevel,
    );

    await _channel.invokeMethod('start', {
      'configJson': jsonEncode(xrayConfig),
      'serverHost': serverIp,
      'mtu': 1500,
    });

    _statusController.add(EngineStatus.connected);
  }

  @override
  Future<void> stop() async {
    _statusController.add(EngineStatus.stopping);
    await _channel.invokeMethod('stop');
    _statusController.add(EngineStatus.stopped);
  }

  @override
  Future<EngineStats> currentStats() async {
    // xray-core stats API not wired up here either — see the same TODO on
    // XrayEngineWindows.
    return const EngineStats(uploadBytes: 0, downloadBytes: 0);
  }

  ServerConfig _pinToResolvedIp(ServerConfig server, String ip) => switch (server) {
    VlessConfig s => VlessConfig(
      address: ip,
      port: s.port,
      uuid: s.uuid,
      flow: s.flow,
      network: s.network,
      security: s.security,
      sni: s.sni ?? s.address,
      publicKey: s.publicKey,
      shortId: s.shortId,
      fingerprint: s.fingerprint,
      xhttpPath: s.xhttpPath,
      xhttpHost: s.xhttpHost ?? s.address,
    ),
    Hysteria2Config s => Hysteria2Config(
      address: ip,
      port: s.port,
      auth: s.auth,
      sni: s.sni ?? s.address,
      insecure: s.insecure,
      obfsPassword: s.obfsPassword,
    ),
  };

  Future<String?> _resolveServerIp(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      return addresses.isEmpty ? null : addresses.first.address;
    } on SocketException {
      return null;
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
