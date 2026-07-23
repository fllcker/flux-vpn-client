import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/features/servers/fake_server.dart';
import 'package:vpn_client/main.dart';

void main() {
  testWidgets('shows the server list and disconnected status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VpnClientApp()));

    expect(find.text('Отключено'), findsOneWidget);
    // Первый сервер выбран по умолчанию — виден и в списке, и в правой панели.
    expect(find.text(fakeServers.first.name), findsNWidgets(2));
    expect(find.text(fakeServers.last.name), findsOneWidget);
  });
}
