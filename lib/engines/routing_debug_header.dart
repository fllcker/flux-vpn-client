/// Диагностический заголовок, который движки (xray/sing-box, Windows/macOS)
/// пишут первой строкой в свой лог-файл при старте — чтобы при разборе
/// `flux_xray_*.log`/`flux_singbox_*.log` сразу было видно, с каким
/// пресетом роутинга шла эта сессия, не сверяясь отдельно с `settings.json`
/// (см. `CoreEngine.start`, `effective_routing.dart`).
String routingDebugHeader({
  required String routingLabel,
  required String defaultOutboundTag,
  required int ruleCount,
}) {
  final timestamp = DateTime.now().toIso8601String();
  return '=== flux session start $timestamp ===\n'
      'routing preset: $routingLabel\n'
      'default outbound (unmatched traffic): $defaultOutboundTag\n'
      'rule count: $ruleCount\n'
      '=======================================\n';
}
