import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core_abstraction/app_settings.dart';
import '../../core_abstraction/server_config.dart';
import '../../engines/xray/child_process_job.dart';
import '../../engines/xray/xray_config_mapper.dart';
import '../../engines/xray/xray_engine_windows.dart' show defaultXrayExecutablePath;

/// Мерит задержку до одного сервера — не привязано к активному подключению
/// (`CoreEngine`), т.к. должно уметь измерять **любой** сервер, включая
/// неактивные, и мерить сразу много серверов, а не только тот, к которому
/// сейчас подключены. См. ROADMAP.md, трек 4.
///
/// `viaProxy` реализован не через встроенный xray-core Observatory (как
/// заложено в ROADMAP.md) — это потребовало бы gRPC-клиента к Stats API,
/// которого в проекте пока нет (см. "Открытые вопросы" в PLAN.md: "Stats
/// API — gRPC или HTTP+логи"). Вместо этого поднимается временный
/// xray-процесс с одним outbound'ом (тот же `buildXrayConfig`, что и у
/// обычного Proxy-подключения) на свободных портах, и через его локальный
/// HTTP-инбаунд замеряется по времени запрос на [pingTestUrl] — тот же
/// итоговый результат ("реальная задержка через прокси, как будет
/// ощущаться"), без протобаф-биндингов.
class PingService {
  const PingService();

  Future<int?> ping(
    ServerConfig config, {
    required PingMode mode,
    required String pingTestUrl,
  }) {
    return switch (mode) {
      PingMode.tcp => pingTcp(config.address, config.port),
      PingMode.icmp => pingIcmp(config.address),
      PingMode.viaProxy => pingViaProxy(config, testUrl: pingTestUrl),
    };
  }

  Future<int?> pingTcp(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(address, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// На Windows нет прямого raw-socket ICMP API без прав администратора,
  /// поэтому используем системную утилиту `ping` (тот же паттерн внешнего
  /// процесса, что и `windows_elevation.dart`/`child_process_job.dart`) и
  /// парсим задержку из вывода.
  Future<int?> pingIcmp(
    String host, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final result = await Process.run('ping', [
        '-n',
        '1',
        '-w',
        '${timeout.inMilliseconds}',
        host,
      ]).timeout(timeout + const Duration(seconds: 2));

      final match = RegExp(
        r'(?:time|время)[=<]\s*(\d+)\s*ms',
        caseSensitive: false,
      ).firstMatch(result.stdout as String? ?? '');
      if (match == null) return null;
      return int.tryParse(match.group(1)!);
    } catch (_) {
      return null;
    }
  }

  Future<int?> pingViaProxy(
    ServerConfig config, {
    required String testUrl,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socksPort = await _freePort();
    final httpPort = await _freePort();
    final xrayConfig = buildXrayConfig(
      config,
      socksPort: socksPort,
      httpPort: httpPort,
    );

    final configFile = await File(
      '${Directory.systemTemp.path}/flux_ping_'
      '${DateTime.now().microsecondsSinceEpoch}.json',
    ).writeAsString(jsonEncode(xrayConfig));

    Process? process;
    try {
      process = await Process.start(defaultXrayExecutablePath(), [
        'run',
        '-c',
        configFile.path,
      ]);
      tieChildProcessLifetimeToApp(process);
      // Даём xray время поднять локальные инбаунды перед первым запросом.
      await Future.delayed(const Duration(milliseconds: 300));

      final client = HttpClient();
      client.findProxy = (_) => 'PROXY 127.0.0.1:$httpPort';
      client.connectionTimeout = timeout;
      final stopwatch = Stopwatch()..start();
      try {
        final request = await client
            .getUrl(Uri.parse(testUrl))
            .timeout(timeout);
        final response = await request.close().timeout(timeout);
        await response.drain<void>();
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    } finally {
      process?.kill();
      await configFile.delete().catchError((_) => configFile);
    }
  }

  Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

const pingService = PingService();
