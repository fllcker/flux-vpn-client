import '../../core_abstraction/proxy_node.dart';

/// Сопоставляет листья только что скачанного дерева подписки ([newRoot]) со
/// старым деревом ([oldRoot], тем, что было в [Subscription.root] до
/// рефреша) — id листьев и вариантов пересоздаются заново при каждом
/// импорте (см. `import_to_proxy_nodes.dart`, `importedServersToLeaves`),
/// поэтому единственный стабильный идентификатор физического сервера — это
/// адрес хоста первого варианта. Для совпавших листьев переносится
/// [ProxyNode.hidden] и [ServerLeaf.selection], а сам лист и совпавшие
/// варианты сохраняют свои старые id — иначе выбор пользователя (`hidden`,
/// `selectedServerIdProvider`, активное подключение по id) слетал бы при
/// каждом обновлении подписки.
///
/// Сервер, пропавший из свежих данных подписки, просто не попадает в
/// результат вместе со своим узлом — сохранять его состояние отдельно не
/// нужно (см. ROADMAP.md, трек 0).
ProxyNode mergeSubscriptionTree(ProxyNode oldRoot, ProxyNode newRoot) {
  final oldByAddress = <String, ServerLeaf>{};
  _indexLeaves(oldRoot, oldByAddress);
  return _merge(newRoot, oldByAddress);
}

void _indexLeaves(ProxyNode node, Map<String, ServerLeaf> out) {
  switch (node) {
    case ServerLeaf leaf:
      final address = _primaryAddress(leaf);
      if (address != null) out[address] = leaf;
    case ServerGroup group:
      for (final child in group.children) {
        _indexLeaves(child, out);
      }
  }
}

ProxyNode _merge(ProxyNode node, Map<String, ServerLeaf> oldByAddress) {
  switch (node) {
    case ServerLeaf leaf:
      final address = _primaryAddress(leaf);
      final old = address == null ? null : oldByAddress[address];
      return old == null ? leaf : _mergeLeaf(old, leaf);
    case ServerGroup group:
      return ServerGroup(
        id: group.id,
        name: group.name,
        icon: group.icon,
        hidden: group.hidden,
        strategy: group.strategy,
        children: [
          for (final child in group.children) _merge(child, oldByAddress),
        ],
      );
  }
}

ServerLeaf _mergeLeaf(ServerLeaf old, ServerLeaf fresh) {
  final variants = [
    for (final variant in fresh.variants)
      _withMatchedId(variant, old.variants) ?? variant,
  ];

  final selection = switch (old.selection) {
    ManualVariantSelection(:final variantId)
        when variants.any((v) => v.id == variantId) =>
      old.selection,
    _ => fresh.selection,
  };

  return ServerLeaf(
    id: old.id,
    name: fresh.name,
    icon: fresh.icon,
    hidden: old.hidden,
    variants: variants,
    selection: selection,
    // Правила роутинга приходят с сервера при каждом импорте (см.
    // `xray_subscription_parser.dart`) — берём свежие, не переносим старые
    // (в отличие от hidden/selection, это не локальный пользовательский
    // выбор, а данные подписки), см. ROADMAP.md, трек 3.
    routingRules: fresh.routingRules,
  );
}

/// Возвращает [variant] с id совпавшего старого варианта (тот же адрес и та
/// же подпись — подпись отличает, например, TCP Reality от XHTTP Reality на
/// одном сервере), либо `null`, если это новый вариант, ранее не
/// встречавшийся у этого сервера.
ConnectionVariant? _withMatchedId(
  ConnectionVariant variant,
  List<ConnectionVariant> oldVariants,
) {
  for (final old in oldVariants) {
    if (old.label == variant.label &&
        old.config.address == variant.config.address) {
      return ConnectionVariant(
        id: old.id,
        label: variant.label,
        config: variant.config,
      );
    }
  }
  return null;
}

String? _primaryAddress(ServerLeaf leaf) {
  if (leaf.variants.isEmpty) return null;
  return leaf.variants.first.config.address;
}
