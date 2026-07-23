import 'core_engine.dart';

typedef CoreEngineFactory = CoreEngine Function(String engineId);

/// Реестр и оркестрация активных [CoreEngine]-инстансов — поддерживает
/// одновременный запуск нескольких ядер/профилей одновременно. Выбор
/// реализации по [CoreType] задаётся через [registerFactory], конкретные
/// платформенные реализации (напр. `XrayEngine` для Windows) регистрируют
/// себя при старте приложения.
///
/// Маршрутизация трафика между несколькими активными ядрами (мульти-хоп,
/// split-tunneling по профилям) — не проектируется сейчас, см. PLAN.md.
class EngineManager {
  final Map<CoreType, CoreEngineFactory> _factories = {};
  final Map<String, CoreEngine> _engines = {};

  void registerFactory(CoreType type, CoreEngineFactory factory) {
    _factories[type] = factory;
  }

  CoreEngine createEngine(CoreType type, String engineId) {
    final factory = _factories[type];
    if (factory == null) {
      throw StateError('No CoreEngine factory registered for $type');
    }
    final engine = factory(engineId);
    _engines[engineId] = engine;
    return engine;
  }

  CoreEngine? engine(String engineId) => _engines[engineId];

  List<CoreEngine> get activeEngines => List.unmodifiable(_engines.values);

  Future<void> removeEngine(String engineId) async {
    final engine = _engines.remove(engineId);
    await engine?.stop();
  }
}
