import 'server_config.dart';

enum GroupStrategy { select, urlTest, fallback, loadBalance }

sealed class VariantSelection {
  const VariantSelection();

  Map<String, dynamic> toJson();

  factory VariantSelection.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'manual' => ManualVariantSelection(json['variantId'] as String),
      'auto' || null => const AutoVariantSelection(),
      _ => throw FormatException('Unknown VariantSelection.type: $type'),
    };
  }
}

class ManualVariantSelection extends VariantSelection {
  final String variantId;
  const ManualVariantSelection(this.variantId);

  @override
  Map<String, dynamic> toJson() => {'type': 'manual', 'variantId': variantId};
}

class AutoVariantSelection extends VariantSelection {
  const AutoVariantSelection();

  @override
  Map<String, dynamic> toJson() => {'type': 'auto'};
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

  factory ConnectionVariant.fromJson(Map<String, dynamic> json) {
    return ConnectionVariant(
      id: json['id'] as String,
      label: json['label'] as String,
      config: ServerConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'config': config.toJson(),
  };
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

  Map<String, dynamic> toJson();

  /// Диспетчер по полю `type`. Незнакомый тип узла ломает всё дерево, а не
  /// только один узел — по правилу обратной совместимости из PLAN.md новый
  /// вариант ProxyNode добавляется только вместе с миграцией схемы.
  factory ProxyNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'leaf' => ServerLeaf.fromJson(json),
      'group' => ServerGroup.fromJson(json),
      _ => throw FormatException('Unknown ProxyNode.type: $type'),
    };
  }
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

  /// Активный вариант подключения по [selection]: конкретный — если
  /// [ManualVariantSelection], иначе первый (авто-выбор по задержке — см.
  /// PLAN.md — пока не реализован).
  ConnectionVariant? get activeVariant {
    if (variants.isEmpty) return null;
    final selection = this.selection;
    if (selection is ManualVariantSelection) {
      return variants.firstWhere(
        (v) => v.id == selection.variantId,
        orElse: () => variants.first,
      );
    }
    return variants.first;
  }

  ServerLeaf withSelection(VariantSelection selection) => ServerLeaf(
    id: id,
    name: name,
    icon: icon,
    hidden: hidden,
    variants: variants,
    selection: selection,
  );

  factory ServerLeaf.fromJson(Map<String, dynamic> json) {
    return ServerLeaf(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      hidden: json['hidden'] as bool? ?? false,
      variants: (json['variants'] as List)
          .map((v) => ConnectionVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
      selection: json['selection'] == null
          ? const AutoVariantSelection()
          : VariantSelection.fromJson(json['selection'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'leaf',
    'id': id,
    'name': name,
    if (icon != null) 'icon': icon,
    'hidden': hidden,
    'variants': variants.map((v) => v.toJson()).toList(),
    'selection': selection.toJson(),
  };
}

/// Ищет [ServerLeaf] с [leafId] в дереве и возвращает копию дерева с его
/// [ServerLeaf.selection], заменённым на выбор [variantId]. Остальные узлы
/// возвращаются как есть.
ProxyNode replaceLeafSelection(ProxyNode node, String leafId, String variantId) {
  return switch (node) {
    ServerLeaf leaf when leaf.id == leafId =>
      leaf.withSelection(ManualVariantSelection(variantId)),
    ServerLeaf leaf => leaf,
    ServerGroup group => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.strategy,
      children: group.children
          .map((c) => replaceLeafSelection(c, leafId, variantId))
          .toList(),
    ),
  };
}

/// Ищет узел с [nodeId] в дереве и возвращает копию дерева с его
/// [ProxyNode.hidden], заменённым на [hidden]. Остальные узлы возвращаются
/// как есть. Скрывать можно и лист, и целую группу, но UI сейчас вызывает
/// это только для листьев внутри подписки (см. ROADMAP.md, трек 2 —
/// standalone-серверы скрытие не поддерживают).
ProxyNode setNodeHidden(ProxyNode node, String nodeId, bool hidden) {
  return switch (node) {
    ServerLeaf leaf when leaf.id == nodeId => ServerLeaf(
      id: leaf.id,
      name: leaf.name,
      icon: leaf.icon,
      hidden: hidden,
      variants: leaf.variants,
      selection: leaf.selection,
    ),
    ServerLeaf leaf => leaf,
    ServerGroup group => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.id == nodeId ? hidden : group.hidden,
      strategy: group.strategy,
      children: group.children
          .map((c) => setNodeHidden(c, nodeId, hidden))
          .toList(),
    ),
  };
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

  factory ServerGroup.fromJson(Map<String, dynamic> json) {
    return ServerGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      hidden: json['hidden'] as bool? ?? false,
      children: (json['children'] as List)
          .map((c) => ProxyNode.fromJson(c as Map<String, dynamic>))
          .toList(),
      strategy: GroupStrategy.values.byName(
        json['strategy'] as String? ?? 'select',
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'id': id,
    'name': name,
    if (icon != null) 'icon': icon,
    'hidden': hidden,
    'strategy': strategy.name,
    'children': children.map((c) => c.toJson()).toList(),
  };
}
