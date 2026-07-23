import 'package:flutter_riverpod/flutter_riverpod.dart';

/// id-ы развёрнутых узлов дерева в сайдбаре — и для [ServerGroup], и для
/// [ServerLeaf] с несколькими вариантами подключения (единая механика
/// раскрытия для обоих случаев, инлайн-аккордеон вместо поповера).
final expandedNodesProvider =
    NotifierProvider<ExpandedNodesController, Set<String>>(
      ExpandedNodesController.new,
    );

class ExpandedNodesController extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }
}
