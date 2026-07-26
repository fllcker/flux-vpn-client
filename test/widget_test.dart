import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/core_abstraction/app_settings.dart';
import 'package:flux/core_abstraction/app_settings_provider.dart';
import 'package:flux/core_abstraction/core_config.dart';
import 'package:flux/core_abstraction/core_config_provider.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/main.dart';

void main() {
  // AppTitleBar talks to the native window_manager plugin (isMaximized,
  // addListener) — there's no native side in widget tests, so without a
  // mock handler those channel calls hang the test run indefinitely.
  const windowManagerChannel = MethodChannel('window_manager');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
          if (call.method == 'isMaximized') return false;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
  });

  testWidgets('shows the empty state when there are no servers yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Не зависим от реального profile.json/settings.json на диске.
          coreConfigProvider.overrideWith(
            () => _PresetCoreConfigController(const CoreConfig()),
          ),
          appSettingsProvider.overrideWith(_PresetAppSettingsController.new),
        ],
        child: FluxApp(
          navigatorKey: GlobalKey<NavigatorState>(),
          incomingDeepLinks: const Stream.empty(),
        ),
      ),
    );

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
          appSettingsProvider.overrideWith(_PresetAppSettingsController.new),
        ],
        child: FluxApp(
          navigatorKey: GlobalKey<NavigatorState>(),
          incomingDeepLinks: const Stream.empty(),
        ),
      ),
    );

    expect(find.text('Отключено'), findsOneWidget);
    // Единственный сервер выбран по умолчанию — виден в списке, в карточке
    // подключения и в подписи маркера на глобусе (страна определяется по
    // флагу 🇩🇪 в icon).
    expect(find.text('Germany #1'), findsNWidgets(3));
  });
}

class _PresetCoreConfigController extends CoreConfigController {
  final CoreConfig initial;
  _PresetCoreConfigController(this.initial);

  @override
  CoreConfig build() => initial;
}

class _PresetAppSettingsController extends AppSettingsController {
  // Фон задан явно, а не взят по умолчанию: тест считает вхождения имени
  // сервера, и третье из них — подпись маркера на глобусе, то есть тест
  // молча зависит от того, какой фон включён. Со сменой умолчания на galaxy
  // он и упал.
  //
  // Язык задан явно (не `system`) — тест ищет русский текст по значению, а
  // локаль тестового окружения Flutter не обязательно `ru` (см.
  // `l10n/app_locale.dart`), так что `system` резолвился бы в английский и
  // ломал сравнение.
  @override
  AppSettings build() => const AppSettings(
    homeBackground: HomeBackground.globe,
    language: AppLanguage.ru,
    // Иначе виджет-тесты вместо ConnectionScreen увидели бы OnboardingFlow
    // (дефолт конструктора — false, см. app_settings.dart) и падали.
    onboardingCompleted: true,
  );
}
