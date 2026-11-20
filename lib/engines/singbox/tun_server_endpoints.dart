import 'dart:io';

import '../../core_abstraction/server_config.dart';

Future<({List<String> additionalHosts, List<String> ips})>
resolveTunServerEndpoints(ServerConfig server) async {
  final downloadAddress = switch (server) {
    VlessConfig config => config.xhttpDownloadAddress,
    _ => null,
  };
  final additionalHosts = [
    if (downloadAddress != null && downloadAddress != server.address)
      downloadAddress,
  ];
  // Resolve before installing the TUN routes so DNS cannot depend on the tunnel.
  // The bootstrap DNS rule also covers hosts that could not be resolved here.
  final addresses = await Future.wait([
    _lookup(server.address),
    for (final host in additionalHosts) _lookup(host),
  ]);
  return (
    additionalHosts: additionalHosts,
    ips: {for (final result in addresses) ...result}.toList(),
  );
}

Future<List<String>> _lookup(String host) async {
  try {
    final addresses = await InternetAddress.lookup(host);
    return [for (final address in addresses) address.address];
  } on SocketException {
    return const [];
  }
}
