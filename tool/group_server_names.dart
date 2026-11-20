import 'dart:convert';
import 'dart:io';

import '../lib/core_abstraction/proxy_node.dart';
import '../lib/features/servers/group_leaves_by_name.dart';

Future<void> main(List<String> args) async {
  const usage =
      'Usage: group-server-names [--flux] [names.txt]\n'
      'Read UTF-8 names, one per line, from a file or stdin.\n'
      'Group by the first word, including groups with a single server.\n'
      'Use --flux to run the grouping algorithm used in Flux.';
  if (args.length == 1 && (args.single == '--help' || args.single == '-h')) {
    stdout.writeln(usage);
    return;
  }
  final useFluxGrouping = args.isNotEmpty && args.first == '--flux';
  final positional = useFluxGrouping ? args.skip(1).toList() : args;
  if (positional.length > 1) {
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }

  try {
    final input = positional.isEmpty
        ? stdin
        : File(positional.single).openRead();
    final names = <String>[];
    await for (final line
        in input.transform(utf8.decoder).transform(const LineSplitter())) {
      final name = line.trim();
      if (name.isEmpty) continue;
      names.add(name);
    }

    final tree = useFluxGrouping
        ? groupLeavesByName([
            for (final (index, name) in names.indexed)
              ServerLeaf(id: '$index', name: name, variants: const []),
          ]).map(_nodeToJson).toList()
        : _groupByFirstWord(names);
    stdout.encoding = utf8;
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(tree));
  } on FileSystemException catch (error) {
    stderr.writeln('Cannot read names: ${error.message}');
    exitCode = 66;
  } on FormatException {
    stderr.writeln('Input must be valid UTF-8.');
    exitCode = 65;
  }
}

List<Map<String, Object>> _groupByFirstWord(List<String> names) {
  final separator = RegExp(r'[\s,/|\-]+');
  final groups = <String, List<Map<String, String>>>{};
  for (final name in names) {
    final split = separator.firstMatch(name);
    final group = split == null || split.start == 0
        ? name
        : name.substring(0, split.start);
    groups.putIfAbsent(group, () => []).add({'name': name});
  }
  return [
    for (final group in groups.entries)
      {'name': group.key, 'children': group.value},
  ];
}

Map<String, Object> _nodeToJson(ProxyNode node) => {
  'name': node.name,
  if (node is ServerGroup) 'children': node.children.map(_nodeToJson).toList(),
};
