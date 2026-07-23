import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core_abstraction/core_config.dart';
import 'package:vpn_client/core_abstraction/core_config_provider.dart';
import 'package:vpn_client/core_abstraction/proxy_node.dart';
import 'package:vpn_client/core_abstraction/server_config.dart';
import 'package:vpn_client/main.dart';

void main() {
  testWidgets('shows the empty state when there are no servers yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VpnClientApp()));

    expect(
      find.text('Пока нет серверов — добавьте подписку или ссылку.'),
      findsOneWidget,
    );
    expect(
      find.text('Выберите сервер слева, чтобы подключиться.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an imported server and lets you select it', (
    WidgetTester tester,
  ) async {
    const leaf = ServerLeaf(
      id: 'leaf-1',
      name: 'Germany #1',
      icon: '🇩🇪',
      variants: [
        ConnectionVariant(
          id: 'variant-1',
          label: 'default',
          config: VlessConfig(
            address: 'de1.example.com',
            port: 443,
            uuid: 'uuid-1',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreConfigProvider.overrideWith(
            () => _PresetCoreConfigController(
              const CoreConfig(standaloneNodes: [leaf]),
            ),
          ),
        ],
        child: const VpnClientApp(),
      ),
    );

    expect(find.text('Отключено'), findsOneWidget);
    // Единственный сервер выбран по умолчанию — виден и в списке, и справа.
    expect(find.text('Germany #1'), findsNWidgets(2));
  });
}

class _PresetCoreConfigController extends CoreConfigController {
  final CoreConfig initial;
  _PresetCoreConfigController(this.initial);

  @override
  CoreConfig build() => initial;
}
