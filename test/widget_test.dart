import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:vpn_client/main.dart';

void main() {
  testWidgets('shows the vless link field and disconnected status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VpnClientApp()));

    expect(find.text('Отключено'), findsOneWidget);
    expect(find.byType(ShadInput), findsOneWidget);
    expect(find.text('Подключиться'), findsOneWidget);
  });
}
