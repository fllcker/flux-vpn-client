import 'package:uuid/uuid.dart';

import '../../core_abstraction/proxy_node.dart';

const _uuid = Uuid();
final _delimiters = RegExp(r'[\s,/|\-]+');
final _numeric = RegExp(r'^\d+$');

class _Entry {
  final ServerLeaf leaf;
  final List<String> segments;
  const _Entry({required this.leaf, required this.segments});
}

/// Автоматическая группировка плоского списка серверов по общим частям
/// названия — как в обычных (не Magic JSON) конфигах, где группа обычно
/// зашита прямо в remarks через разделитель: "Basic - Germany 1",
/// "Basic - Finland 1", "Premium - Sweden 1" → группа Basic (Germany 1,
/// Finland 1); "Premium - Sweden 1" остаётся плоским листом — группа не
/// создаётся ради одного элемента.
///
/// Если подряд идущие части названия разделяют вообще все элементы набора
/// ("For", затем "Anitype", затем "for", затем "AniType" — и так у каждого
/// сервера в наборе), это не настоящее ветвление, а общий префикс без
/// какой-либо развилки — на каждую такую часть отдельный уровень группы не
/// заводится, они схлопываются в одну группу с именем последней общей
/// части.
List<ProxyNode> groupLeavesByName(List<ServerLeaf> leaves) {
  final entries = leaves
      .map((leaf) => _Entry(leaf: leaf, segments: _tokenize(leaf.name)))
      .toList();
  return _group(entries, null);
}

List<String> _tokenize(String name) => name
    .split(_delimiters)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

List<ProxyNode> _group(List<_Entry> entries, String? parentGroupName) {
  if (entries.length <= 1) {
    return entries.map((e) => _toLeaf(e, parentGroupName)).toList();
  }

  // Схлопываем часть пути, которую делят вообще все элементы набора — тут
  // ещё нет развилки, тратить на каждый такой сегмент отдельный уровень
  // группы не нужно.
  var current = entries;
  final compressed = <String>[];
  while (current.every((e) => e.segments.isNotEmpty)) {
    final key = current.first.segments.first;
    if (!current.every((e) => e.segments.first == key)) break;
    compressed.add(key);
    current = current
        .map((e) => _Entry(leaf: e.leaf, segments: e.segments.skip(1).toList()))
        .toList();
  }

  if (compressed.isNotEmpty) {
    final name = compressed.last;
    return [
      ServerGroup(id: _uuid.v4(), name: name, children: _group(current, name)),
    ];
  }

  final byFirst = <String, List<_Entry>>{};
  final order = <String>[];
  final terminal = <_Entry>[];
  for (final entry in current) {
    if (entry.segments.isEmpty) {
      terminal.add(entry);
      continue;
    }
    final key = entry.segments.first;
    if (!byFirst.containsKey(key)) order.add(key);
    byFirst.putIfAbsent(key, () => []).add(entry);
  }

  // Группа имеет смысл, только если хотя бы одна ветка реально объединяет
  // больше одного элемента — иначе это не группировка, а просто разные
  // серверы.
  final hasRealBranch = order.any((key) => byFirst[key]!.length > 1);
  if (!hasRealBranch) {
    return current.map((e) => _toLeaf(e, parentGroupName)).toList();
  }

  return [
    for (final entry in terminal) _toLeaf(entry, parentGroupName),
    for (final key in order)
      if (byFirst[key]!.length > 1)
        ServerGroup(
          id: _uuid.v4(),
          name: key,
          children: _group(
            byFirst[key]!
                .map(
                  (e) => _Entry(leaf: e.leaf, segments: e.segments.skip(1).toList()),
                )
                .toList(),
            key,
          ),
        )
      else
        _toLeaf(byFirst[key]!.single, parentGroupName),
  ];
}

/// Если от имени остался голый номер ("1"), дублируем в него имя
/// ближайшей группы ("Germany 1") — само по себе число как имя сервера
/// нечитаемо.
ServerLeaf _toLeaf(_Entry entry, String? parentGroupName) {
  final segments = entry.segments;
  final String name;
  if (segments.isEmpty) {
    name = entry.leaf.name;
  } else if (parentGroupName != null &&
      segments.length == 1 &&
      _numeric.hasMatch(segments.single)) {
    name = '$parentGroupName ${segments.single}';
  } else {
    name = segments.join(' ');
  }

  final leaf = entry.leaf;
  return ServerLeaf(
    id: leaf.id,
    name: name,
    icon: leaf.icon,
    hidden: leaf.hidden,
    variants: leaf.variants,
    selection: leaf.selection,
  );
}
