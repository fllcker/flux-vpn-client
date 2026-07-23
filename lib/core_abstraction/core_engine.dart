import 'core_config.dart';

enum CoreType { xray, singbox }

enum EngineStatus { stopped, starting, connected, stopping, error }

class EngineStats {
  final int uploadBytes;
  final int downloadBytes;
  final Duration? latency;

  const EngineStats({
    required this.uploadBytes,
    required this.downloadBytes,
    this.latency,
  });
}

/// Общий контракт для любого VPN-ядра (xray-core, sing-box, ...).
/// UI и бизнес-стейт работают только через этот интерфейс — конкретное
/// ядро выбирается и подключается через [EngineManager].
abstract class CoreEngine {
  String get id;
  CoreType get type;

  Stream<EngineStatus> get statusStream;
  Stream<EngineStats> get statsStream;

  Future<void> start(CoreConfig config);
  Future<void> stop();
  Future<EngineStats> currentStats();
}
