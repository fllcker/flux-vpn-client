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

  // Человекочитаемое имя действующего пресета роутинга ("server-routing"
  // для дефолтного "Роутинга сервера") — только для диагностики: пишется
  // заголовком в лог-файл движка (`flux_xray_*.log`/`flux_singbox_*.log`,
  // см. `_pipeLogs` в конкретных движках), чтобы при разборе лога сразу
  // было видно, с каким пресетом шла сессия, не сверяясь отдельно с
  // `settings.json`.
  Future<void> start(
    CoreConfig config, {
    String defaultOutboundTag = 'proxy',
    String routingLabel = 'server-routing',
  });
  Future<void> stop();
  Future<EngineStats> currentStats();
}
