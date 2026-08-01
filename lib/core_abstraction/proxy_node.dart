import 'server_config.dart';

enum GroupStrategy { select, urlTest, fallback, loadBalance }

/// Правило роутинга. Живёт на [ServerLeaf] (в xray-json подписке роутинг
/// обычно приходит отдельным блоком `"routing"` внутри JSON-объекта каждого
/// сервера) — это фоллбек-набор для пресета "Роутинг сервера". Основной
/// UX-путь теперь — именованные [RoutingPreset] (`routing_preset.dart`),
/// один из которых выбирается активным на уровне приложения
/// (`AppSettings.activeRoutingPresetId`) и подменяет правила листа для всех
/// серверов сразу, см. `effective_routing.dart`.
///
/// Значения в [DomainRule.values]/[IpRule.values] хранятся как есть, один в
/// один с xray-шным синтаксисом (`"example.com"`, `"domain:sub.example.com"`,
/// `"regexp:..."`, `"geosite:category-ads"` для доменов;
/// `"1.2.3.0/24"`, `"geoip:cn"` для IP) — xray сам допускает смешивать
/// голые значения и `geosite:`/`geoip:`-префиксы в одном списке, поэтому
/// отдельных типов правил под geosite/geoip не заводим.
sealed class RoutingRule {
  const RoutingRule();

  Map<String, dynamic> toJson();

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'domain' => DomainRule.fromJson(json),
      'ip' => IpRule.fromJson(json),
      _ => throw FormatException('Unknown RoutingRule.type: $type'),
    };
  }
}

class DomainRule extends RoutingRule {
  final List<String> values;
  final String outboundTag; // "direct" | "block" | "proxy"

  const DomainRule({required this.values, required this.outboundTag});

  factory DomainRule.fromJson(Map<String, dynamic> json) => DomainRule(
    values: (json['values'] as List).cast<String>(),
    outboundTag: json['outboundTag'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'domain',
    'values': values,
    'outboundTag': outboundTag,
  };
}

class IpRule extends RoutingRule {
  final List<String> values;
  final String outboundTag; // "direct" | "block" | "proxy"

  const IpRule({required this.values, required this.outboundTag});

  factory IpRule.fromJson(Map<String, dynamic> json) => IpRule(
    values: (json['values'] as List).cast<String>(),
    outboundTag: json['outboundTag'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ip',
    'values': values,
    'outboundTag': outboundTag,
  };
}

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
      'auto' => AutoSelectMarker.fromJson(json),
      _ => throw FormatException('Unknown ProxyNode.type: $type'),
    };
  }
}

/// Псевдо-узел "Авто" — не сервер, а маркер, который автогруппировка
/// (`insert_auto_select_markers.dart`) вставляет первым элементом в каждую
/// `ServerGroup.children`. Клик по нему в UI один раз выбирает сервер с
/// наименьшей задержкой среди листьев группы (см.
/// `pick_best_by_latency.dart`) — не отдельный узел подключения сам по
/// себе, реального `ServerConfig` тут нет. V1 — разовый выбор, не live
/// failover, см. ROADMAP.md, трек 5.
class AutoSelectMarker extends ProxyNode {
  const AutoSelectMarker({required super.id, super.name = 'Авто'});

  factory AutoSelectMarker.fromJson(Map<String, dynamic> json) =>
      AutoSelectMarker(id: json['id'] as String, name: json['name'] as String);

  @override
  Map<String, dynamic> toJson() => {'type': 'auto', 'id': id, 'name': name};
}

class ServerLeaf extends ProxyNode {
  final List<ConnectionVariant> variants;
  final VariantSelection selection;
  final List<RoutingRule> routingRules; // [] = нет своих правил — весь
  // трафик через прокси, как раньше

  const ServerLeaf({
    required super.id,
    required super.name,
    super.icon,
    super.hidden,
    required this.variants,
    this.selection = const AutoVariantSelection(),
    this.routingRules = const [],
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
    routingRules: routingRules,
  );

  ServerLeaf withRoutingRules(List<RoutingRule> routingRules) => ServerLeaf(
    id: id,
    name: name,
    icon: icon,
    hidden: hidden,
    variants: variants,
    selection: selection,
    routingRules: routingRules,
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
      routingRules: ((json['routingRules'] as List?) ?? const [])
          .map((r) => RoutingRule.fromJson(r as Map<String, dynamic>))
          .toList(),
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
    'routingRules': routingRules.map((r) => r.toJson()).toList(),
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
    AutoSelectMarker marker => marker,
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
      routingRules: leaf.routingRules,
    ),
    ServerLeaf leaf => leaf,
    AutoSelectMarker marker => marker,
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

/// Ищет [ServerGroup] с [groupId] в дереве и возвращает копию дерева с его
/// [ServerGroup.strategy], заменённой на [strategy]. Остальные узлы
/// возвращаются как есть — используется, когда пользователь кликает "Авто"
/// на группе (см. `pick_best_by_latency.dart`), чтобы запомнить сам факт
/// выбора авто-режима для этой группы, см. ROADMAP.md, трек 5.
ProxyNode setGroupStrategy(ProxyNode node, String groupId, GroupStrategy strategy) {
  return switch (node) {
    ServerLeaf leaf => leaf,
    AutoSelectMarker marker => marker,
    ServerGroup group => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.id == groupId ? strategy : group.strategy,
      children: group.children
          .map((c) => setGroupStrategy(c, groupId, strategy))
          .toList(),
    ),
  };
}

/// Перемещает узел [nodeId] в [root] так, чтобы он стал элементом с индексом
/// [newIndex] в `children` группы [newParentGroupId] — драг-н-дроп сортировки
/// внутри одного дерева (одной подписки), см. ROADMAP.md, трек 6.
/// [AutoSelectMarker] никогда не перетаскивается — вставка перед ним (индекс
/// 0 группы, где он есть) сдвигается на 1, чтобы он остался первым.
///
/// Если [nodeId] или [newParentGroupId] не нашлись в этом же дереве —
/// no-op, возвращает [root] как есть (а не дерево с уже вырезанным, но
/// никуда не вставленным узлом): так перетаскивание между разными деревьями
/// (другой подпиской/standalone-списком) безопасно проваливается в ничего
/// не делающий вызов вместо потери сервера.
ProxyNode moveNodeInTree(
  ProxyNode root,
  String nodeId,
  String newParentGroupId,
  int newIndex,
) {
  final extraction = _extractNode(root, nodeId);
  final removed = extraction.removed;
  if (removed == null || removed is AutoSelectMarker) return root;
  if (!_containsGroup(extraction.tree, newParentGroupId)) return root;
  return _insertNode(extraction.tree, newParentGroupId, newIndex, removed);
}

class _Extraction {
  final ProxyNode? removed;
  final ProxyNode tree;
  const _Extraction(this.removed, this.tree);
}

_Extraction _extractNode(ProxyNode node, String nodeId) {
  return switch (node) {
    ServerLeaf leaf => _Extraction(null, leaf),
    AutoSelectMarker marker => _Extraction(null, marker),
    ServerGroup group => _extractFromGroup(group, nodeId),
  };
}

_Extraction _extractFromGroup(ServerGroup group, String nodeId) {
  ProxyNode? removed;
  final newChildren = <ProxyNode>[];
  for (final child in group.children) {
    if (removed == null && child.id == nodeId && child is! AutoSelectMarker) {
      removed = child;
      continue;
    }
    if (removed == null) {
      final result = _extractNode(child, nodeId);
      removed = result.removed;
      newChildren.add(result.tree);
    } else {
      newChildren.add(child);
    }
  }
  return _Extraction(
    removed,
    ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.strategy,
      children: newChildren,
    ),
  );
}

bool _containsGroup(ProxyNode node, String groupId) {
  return switch (node) {
    ServerLeaf() => false,
    AutoSelectMarker() => false,
    ServerGroup group =>
      group.id == groupId || group.children.any((c) => _containsGroup(c, groupId)),
  };
}

ProxyNode _insertNode(
  ProxyNode node,
  String parentGroupId,
  int index,
  ProxyNode toInsert,
) {
  return switch (node) {
    ServerLeaf leaf => leaf,
    AutoSelectMarker marker => marker,
    ServerGroup group when group.id == parentGroupId => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.strategy,
      children: _insertAt(group.children, index, toInsert),
    ),
    ServerGroup group => ServerGroup(
      id: group.id,
      name: group.name,
      icon: group.icon,
      hidden: group.hidden,
      strategy: group.strategy,
      children: group.children
          .map((c) => _insertNode(c, parentGroupId, index, toInsert))
          .toList(),
    ),
  };
}

List<ProxyNode> _insertAt(List<ProxyNode> children, int index, ProxyNode toInsert) {
  // AutoSelectMarker всегда остаётся первым элементом группы.
  final minIndex = children.isNotEmpty && children.first is AutoSelectMarker ? 1 : 0;
  final clamped = index.clamp(minIndex, children.length);
  return [
    ...children.sublist(0, clamped),
    toInsert,
    ...children.sublist(clamped),
  ];
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
