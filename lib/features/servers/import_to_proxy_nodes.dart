import 'package:uuid/uuid.dart';

import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';
import 'derive_server_icon.dart';
import 'import_result.dart';

const _uuid = Uuid();

/// Импортированные серверы с одинаковым [VlessConfig.address] — это один
/// физический сервер с несколькими вариантами подключения (разные
/// транспорты/security), а не разные серверы: панели часто отдают такие
/// варианты отдельными записями с суффиксом в remarks вроде
/// "Germany 1 (xhttp)". Группируем по адресу в один [ServerLeaf] — см.
/// PLAN.md, "Несколько инбаундов на одном сервере".
List<ServerLeaf> importedServersToLeaves(List<ImportedServer> servers) {
  final byAddress = <String, List<ImportedServer>>{};
  for (final server in servers) {
    byAddress.putIfAbsent(server.config.address, () => []).add(server);
  }

  return byAddress.values.map((group) {
    final derived = deriveServerIcon(group.first.name);
    final leafName = _stripVariantSuffix(derived.name);

    final variants = group
        .map(
          (server) => ConnectionVariant(
            id: _uuid.v4(),
            label: _variantLabel(server.config),
            config: server.config,
          ),
        )
        .toList();

    return ServerLeaf(
      id: _uuid.v4(),
      name: leafName,
      icon: derived.icon,
      variants: variants,
      selection: ManualVariantSelection(variants.first.id),
      // Правила роутинга берём у первого варианта — в норме одинаковые у
      // всех вариантов одного сервера (см. ROADMAP.md, трек 3).
      routingRules: group.first.routingRules,
    );
  }).toList();
}

final _variantSuffix = RegExp(r'\s*\([^)]*\)\s*$');

String _stripVariantSuffix(String name) => name.replaceFirst(_variantSuffix, '');

String _variantLabel(ServerConfig config) => switch (config) {
  VlessConfig config => _vlessVariantLabel(config),
  Hysteria2Config config =>
    config.obfsPassword == null ? 'Hysteria2' : 'Hysteria2 Obfs',
};

String _vlessVariantLabel(VlessConfig config) {
  final network = switch (config.network) {
    VlessNetwork.tcp => 'TCP',
    VlessNetwork.xhttp => 'XHTTP',
  };
  final security = switch (config.security) {
    VlessSecurity.none => null,
    VlessSecurity.tls => 'TLS',
    VlessSecurity.reality => 'Reality',
  };
  return security == null ? network : '$network $security';
}
