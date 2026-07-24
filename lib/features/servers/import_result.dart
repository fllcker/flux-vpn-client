import '../../core_abstraction/server_config.dart';

class ImportedServer {
  final String name;
  final ServerConfig config;

  const ImportedServer({required this.name, required this.config});
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
