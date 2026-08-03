import 'dart:io';

/// Системный прокси macOS через `networksetup` — аналог
/// `windows_system_proxy.dart`'s реестровой записи, см. PLAN.md, "Системная
/// интеграция VPN на macOS". В отличие от Windows (один `ProxyServer` ключ
/// на всё), `networksetup` требует отдельных вызовов на HTTP/HTTPS/SOCKS и
/// на каждый сетевой сервис (Wi-Fi, Ethernet, ...) по отдельности — поэтому
/// применяем ко всем сервисам сразу, как большинство VPN-клиентов на macOS,
/// а не только к "активному" (которого API не выдаёт напрямую).
Future<void> enableMacosSystemProxy({required int httpPort}) async {
  for (final service in await _networkServices()) {
    await Process.run('networksetup', [
      '-setwebproxy',
      service,
      '127.0.0.1',
      '$httpPort',
    ]);
    await Process.run('networksetup', [
      '-setsecurewebproxy',
      service,
      '127.0.0.1',
      '$httpPort',
    ]);
  }
}

Future<void> disableMacosSystemProxy() async {
  for (final service in await _networkServices()) {
    await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
    await Process.run('networksetup', [
      '-setsecurewebproxystate',
      service,
      'off',
    ]);
  }
}

/// `networksetup -listallnetworkservices` печатает заголовок первой строкой
/// и звёздочкой перед именем отключённых сервисов (например `*Ethernet`) —
/// такие фильтруем, включать прокси на выключенном интерфейсе бессмысленно.
Future<List<String>> _networkServices() async {
  final result = await Process.run('networksetup', ['-listallnetworkservices']);
  final lines = (result.stdout as String).split('\n');
  return [
    for (final line in lines.skip(1))
      if (line.trim().isNotEmpty && !line.startsWith('*')) line.trim(),
  ];
}
