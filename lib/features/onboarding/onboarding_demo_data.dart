import '../../core_abstraction/proxy_node.dart';
import '../../core_abstraction/server_config.dart';

/// Фейковое дерево серверов для интерактивного шага гайда
/// (`onboarding_steps.dart`, `_GuideDemoStep`) — не настоящие данные,
/// демонстрирует сразу и группировку папками (тап по группе разворачивает
/// детей), и drag-and-drop сортировку (см. `ProxyTreeList.onReorder`) на
/// узнаваемом, но безопасном для тестирования наборе узлов. `VlessConfig`
/// с минимальным набором полей (`address`/`port`/`uuid`) — единственное,
/// что реально требует `ConnectionVariant`, значения никогда никуда не
/// подключаются.
List<ProxyNode> buildOnboardingDemoNodes() {
  ServerLeaf demoLeaf(String id, String name) => ServerLeaf(
    id: id,
    name: name,
    variants: [
      ConnectionVariant(
        id: '${id}_v1',
        label: name,
        config: VlessConfig(address: 'demo.example', port: 443, uuid: id),
      ),
    ],
  );

  return [
    demoLeaf('demo_standalone', 'Demo Server'),
    ServerGroup(
      id: 'demo_group',
      name: 'Demo Group',
      children: [
        demoLeaf('demo_group_1', 'Demo Server 1'),
        demoLeaf('demo_group_2', 'Demo Server 2'),
      ],
    ),
  ];
}
