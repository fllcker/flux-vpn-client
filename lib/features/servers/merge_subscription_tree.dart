import '../../core_abstraction/proxy_node.dart';
import 'group_leaves_by_name.dart';
import 'insert_auto_select_markers.dart';

/// Сопоставляет листья только что скачанного дерева подписки ([newRoot]) со
/// старым деревом ([oldRoot], тем, что было в [Subscription.root] до
/// рефреша) — id листьев и вариантов пересоздаются заново при каждом
/// импорте (см. `import_to_proxy_nodes.dart`, `importedServersToLeaves`),
/// поэтому единственный стабильный идентификатор физического сервера — это
/// адрес хоста первого варианта.
///
/// **Порядок/группировка сохраняются от [oldRoot]** — в т.ч. ручная
/// drag-and-drop сортировка (см. ROADMAP.md, трек 6): функция обходит
/// СТАРОЕ дерево как основу (`_preserveStructure`), для каждого листа
/// подтягивает свежее содержимое по адресу (`_mergeLeaf` — id/hidden/
/// selection остаются старыми, variants/routingRules/name/icon берутся
/// свежими), удаляет серверы, пропавшие из источника, и в конце
/// дописывает (`_appendNewLeaves`) серверы, которых не было в старом
/// дереве — в подходящую по имени существующую группу, если такая
/// нашлась, иначе новой группой/листом в конец. Группировка новых узлов
/// по имени — та же `groupLeavesByName`, что и при первом импорте.
///
/// Если нужно наоборот — отбросить ручную сортировку и пересобрать дерево
/// заново из источника (кнопка "Сбросить сортировку" в
/// `subscription_info_panel.dart`) — см. [resetSubscriptionOrder]: имя
/// группы восстановить из уже сохранённых листьев нельзя (префикс группы
/// вроде "Basic - " вырезается из remarks и нигде не хранится отдельно от
/// самой группировки, см. `group_leaves_by_name.dart`), поэтому "сброс"
/// возможен только вместе с повторной загрузкой подписки с сервера.
ProxyNode mergeSubscriptionTree(ProxyNode oldRoot, ProxyNode newRoot) {
  final newByAddress = <String, ServerLeaf>{};
  _indexLeaves(newRoot, newByAddress);

  final consumed = <String>{};
  final preserved = _preserveStructure(oldRoot, newByAddress, consumed);

  final newLeaves = [
    for (final entry in newByAddress.entries)
      if (!consumed.contains(entry.key)) entry.value,
  ];

  if (preserved is! ServerGroup) {
    // Старое дерево целиком осиротело (все серверы пропали из источника) —
    // сохранять структуру не с чем, берём свежее дерево как есть.
    return newRoot;
  }
  if (newLeaves.isEmpty) return preserved;
  return _appendNewLeaves(preserved, newLeaves);
}

/// Обходит СТАРОЕ дерево, подтягивая свежее содержимое совпавших по адресу
/// листьев (см. [_mergeLeaf]); лист без пары в [newByAddress] пропал из
/// источника — дропается. Группа, где не осталось ничего, кроме
/// [AutoSelectMarker] (или совсем ничего), тоже дропается — пустая группа
/// бесполезна (см. `filter_hidden_nodes.dart`, тот же принцип).
ProxyNode? _preserveStructure(
  ProxyNode node,
  Map<String, ServerLeaf> newByAddress,
  Set<String> consumed,
) {
  switch (node) {
    case ServerLeaf leaf:
      final address = _primaryAddress(leaf);
      final fresh = address == null ? null : newByAddress[address];
      if (fresh == null) return null;
      consumed.add(address!);
      return _mergeLeaf(leaf, fresh);
    case AutoSelectMarker marker:
      return marker;
    case ServerGroup group:
      final children = <ProxyNode>[];
      for (final child in group.children) {
        final merged = _preserveStructure(child, newByAddress, consumed);
        if (merged != null) children.add(merged);
      }
      if (children.every((c) => c is AutoSelectMarker)) return null;
      return ServerGroup(
        id: group.id,
        name: group.name,
        icon: group.icon,
        hidden: group.hidden,
        strategy: group.strategy,
        children: children,
      );
  }
}

/// Дописывает [newLeaves] (серверы, которых не было в старом дереве) в
/// [root]. Сперва пытается пристроить каждый лист в СУЩЕСТВУЮЩУЮ
/// одноимённую группу верхнего уровня — по префиксу имени ("Germany 2"
/// начинается с "Germany " → идёт в группу "Germany"), это работает и для
/// одного нового сервера, в отличие от `groupLeavesByName` (та не образует
/// группу ради одного элемента — см. `group_leaves_by_name.dart`).
/// Оставшиеся (для которых не нашлось подходящей группы) прогоняются через
/// `groupLeavesByName` вместе — так несколько новых серверов одной новой
/// категории всё равно сгруппируются между собой.
ServerGroup _appendNewLeaves(ServerGroup root, List<ServerLeaf> newLeaves) {
  final children = List<ProxyNode>.of(root.children);
  final unplaced = <ServerLeaf>[];

  for (final leaf in newLeaves) {
    final existingIndex = children.indexWhere(
      (c) => c is ServerGroup && leaf.name.startsWith('${c.name} '),
    );
    if (existingIndex == -1) {
      unplaced.add(leaf);
      continue;
    }
    final existing = children[existingIndex] as ServerGroup;
    children[existingIndex] = ServerGroup(
      id: existing.id,
      name: existing.name,
      icon: existing.icon,
      hidden: existing.hidden,
      strategy: existing.strategy,
      children: [...existing.children, leaf],
    );
  }

  for (final newNode in groupLeavesByName(unplaced)) {
    children.add(insertAutoSelectMarkers(newNode));
  }

  return ServerGroup(
    id: root.id,
    name: root.name,
    icon: root.icon,
    hidden: root.hidden,
    strategy: root.strategy,
    children: children,
  );
}

/// Пересобирает дерево заново из свежих данных источника ([newRoot]),
/// отбрасывая любую ручную сортировку/группировку — сохраняются только
/// [ProxyNode.hidden] и [ServerLeaf.selection] совпавших по адресу
/// листьев (routingRules всегда берутся свежими, см. ROADMAP.md, трек 3).
/// В отличие от [mergeSubscriptionTree], обходит НОВОЕ дерево, поэтому
/// порядок/группировка получаются ровно такими же, как при первом импорте
/// подписки — см. ROADMAP.md, трек 6, "Сброс сортировки".
ProxyNode resetSubscriptionOrder(ProxyNode oldRoot, ProxyNode newRoot) {
  final oldByAddress = <String, ServerLeaf>{};
  _indexLeaves(oldRoot, oldByAddress);
  return _merge(newRoot, oldByAddress);
}

void _indexLeaves(ProxyNode node, Map<String, ServerLeaf> out) {
  switch (node) {
    case ServerLeaf leaf:
      final address = _primaryAddress(leaf);
      if (address != null) out[address] = leaf;
    case AutoSelectMarker():
      break;
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
    case AutoSelectMarker marker:
      return marker;
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
