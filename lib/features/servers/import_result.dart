import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';

class ImportedServer {
  final String name;
  final ServerConfig config;
  // Правила роутинга этого сервера, если панель их отдаёт (только
  // xray-json подписки — см. `xray_subscription_parser.dart`). Пусто у
  // остальных источников (vless:// ссылки, base64-подписки).
  final List<RoutingRule> routingRules;

  const ImportedServer({
    required this.name,
    required this.config,
    this.routingRules = const [],
  });
}

/// Запись подписки, которую не удалось привести к Magic JSON — например,
/// протокол, который парсер ещё не понимает (сейчас VLESS и Hysteria2).
class ImportSkipped {
  final String label;
  final String reason;

  const ImportSkipped({required this.label, required this.reason});
}

class SubscriptionImportResult {
  final List<ImportedServer> servers;
  final List<ImportSkipped> skipped;

  const SubscriptionImportResult({
    required this.servers,
    required this.skipped,
  });
}
