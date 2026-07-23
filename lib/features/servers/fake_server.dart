/// Заглушка сервера для прототипа экрана — заменится на реальный
/// ProxyNode/ServerLeaf, когда экран будет подключён к Core Abstraction
/// Layer (см. lib/core_abstraction/proxy_node.dart).
class FakeServer {
  final String id;
  final String name;
  final String icon;
  final int pingMs;

  const FakeServer({
    required this.id,
    required this.name,
    required this.icon,
    required this.pingMs,
  });
}

const fakeServers = <FakeServer>[
  FakeServer(id: 'nl-1', name: 'Netherlands #1', icon: '🇳🇱', pingMs: 39),
  FakeServer(id: 'de-1', name: 'Germany #1', icon: '🇩🇪', pingMs: 42),
  FakeServer(id: 'de-2', name: 'Germany #2', icon: '🇩🇪', pingMs: 58),
  FakeServer(id: 'pl-1', name: 'Poland', icon: '🇵🇱', pingMs: 71),
  FakeServer(id: 'us-1', name: 'USA — New York', icon: '🇺🇸', pingMs: 132),
  FakeServer(id: 'jp-1', name: 'Japan — Tokyo', icon: '🇯🇵', pingMs: 210),
];
