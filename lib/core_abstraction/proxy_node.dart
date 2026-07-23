import 'server_config.dart';

enum GroupStrategy { select, urlTest, fallback, loadBalance }

sealed class VariantSelection {
  const VariantSelection();
}

class ManualVariantSelection extends VariantSelection {
  final String variantId;
  const ManualVariantSelection(this.variantId);
}

class AutoVariantSelection extends VariantSelection {
  const AutoVariantSelection();
}

/// Один физический сервер может иметь несколько вариантов подключения
/// (vless-tcp-reality / vless-xhttp-reality / hysteria2 / ...) — см. PLAN.md,
/// "Несколько инбаундов на одном сервере".
class ConnectionVariant {
  final String id;
  final String label;
  final ServerConfig config;

  const ConnectionVariant({
    required this.id,
    required this.label,
    required this.config,
  });
}

/// Рекурсивный узел дерева серверов/групп — группа и сервер имеют общий
/// интерфейс, поэтому вложенность групп не ограничена без специального кода.
/// См. PLAN.md, "Иерархическая группировка серверов".
sealed class ProxyNode {
  final String id;
  final String name;
  final String? icon; // любой эмодзи, не только флаги
  final bool hidden; // скрыт из основного списка, но остаётся в профиле

  const ProxyNode({
    required this.id,
    required this.name,
    this.icon,
    this.hidden = false,
  });
}

class ServerLeaf extends ProxyNode {
  final List<ConnectionVariant> variants;
  final VariantSelection selection;

  const ServerLeaf({
    required super.id,
    required super.name,
    super.icon,
    super.hidden,
    required this.variants,
    this.selection = const AutoVariantSelection(),
  });
}

class ServerGroup extends ProxyNode {
  final List<ProxyNode> children; // порядок = порядок списка
  final GroupStrategy strategy;

  const ServerGroup({
    required super.id,
    required super.name,
    super.icon,
    super.hidden,
    required this.children,
    this.strategy = GroupStrategy.select,
  });
}
