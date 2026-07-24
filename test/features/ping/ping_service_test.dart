import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/ping/ping_service.dart';

void main() {
  test('pingTcp measures a successful connection', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());

    final latency = await pingService.pingTcp(
      '127.0.0.1',
      server.port,
      timeout: const Duration(seconds: 2),
    );

    expect(latency, isNotNull);
    expect(latency, greaterThanOrEqualTo(0));
  });

  test('pingTcp returns null when the connection is refused', () async {
    // Свободный порт, который тут же закрывается — соединение должно
    // получить отказ, а не зависнуть до таймаута.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();

    final latency = await pingService.pingTcp(
      '127.0.0.1',
      port,
      timeout: const Duration(seconds: 2),
    );

    expect(latency, isNull);
  });
}
