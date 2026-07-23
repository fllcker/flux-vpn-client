import 'core_engine.dart';

enum ConnectionMode { proxy, tun }

/// Состояние одной активной сессии подключения через конкретный [CoreEngine].
/// Режим (proxy/TUN) — параметр сессии, не свойство ядра, см. PLAN.md,
/// "Режимы подключения".
class ConnectionSession {
  final String id;
  final String engineId;
  final ConnectionMode mode;
  final EngineStatus status;

  const ConnectionSession({
    required this.id,
    required this.engineId,
    required this.mode,
    required this.status,
  });
}
