import 'package:uuid/uuid.dart';

import '../../core_abstraction/proxy_node.dart';
import 'derive_server_icon.dart';
import 'import_result.dart';

const _uuid = Uuid();

/// Каждый импортированный сервер — отдельный [ServerLeaf] с одним вариантом
/// подключения. Слияние нескольких вариантов одного физического сервера в
/// один [ServerLeaf] (см. PLAN.md, "Несколько инбаундов на одном сервере")
/// пока не делается — нет надёжного способа понять, что два разных outbound
/// ведут на один и тот же сервер, кроме эвристик по адресу.
List<ServerLeaf> importedServersToLeaves(List<ImportedServer> servers) {
  return servers.map((server) {
    final variantId = _uuid.v4();
    final derived = deriveServerIcon(server.name);
    return ServerLeaf(
      id: _uuid.v4(),
      name: derived.name,
      icon: derived.icon,
      variants: [
        ConnectionVariant(
          id: variantId,
          label: server.name,
          config: server.config,
        ),
      ],
      selection: ManualVariantSelection(variantId),
    );
  }).toList();
}
