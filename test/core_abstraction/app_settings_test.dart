import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/app_settings.dart';
import 'package:flux/core_abstraction/connection_session.dart';

void main() {
  group('AppSettings.fromJson — autoStartPrivilege back-compat (трек 24)', () {
    test('migrates legacy autoStartOnBoot: true to standard', () {
      final settings = AppSettings.fromJson({'autoStartOnBoot': true});
      expect(settings.autoStartPrivilege, AppAutoStartPrivilege.standard);
    });

    test('migrates legacy autoStartOnBoot: false to none', () {
      final settings = AppSettings.fromJson({'autoStartOnBoot': false});
      expect(settings.autoStartPrivilege, AppAutoStartPrivilege.none);
    });

    test('defaults to none when neither field is present', () {
      final settings = AppSettings.fromJson({});
      expect(settings.autoStartPrivilege, AppAutoStartPrivilege.none);
    });

    test('prefers the new field over the legacy one once present', () {
      final settings = AppSettings.fromJson({
        'autoStartOnBoot': true,
        'autoStartPrivilege': 'elevated',
      });
      expect(settings.autoStartPrivilege, AppAutoStartPrivilege.elevated);
    });
  });

  test('AppSettings round-trips new autostart/autoconnect fields through JSON', () {
    const settings = AppSettings(
      autoStartPrivilege: AppAutoStartPrivilege.elevated,
      autoStartShowWindow: true,
      autoConnectOnStartup: true,
      autoConnectMode: ConnectionMode.tun,
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.autoStartPrivilege, AppAutoStartPrivilege.elevated);
    expect(restored.autoStartShowWindow, isTrue);
    expect(restored.autoConnectOnStartup, isTrue);
    expect(restored.autoConnectMode, ConnectionMode.tun);
  });

  test('AppSettings.copyWith updates autostart/autoconnect fields independently', () {
    const settings = AppSettings();
    final updated = settings.copyWith(
      autoStartPrivilege: AppAutoStartPrivilege.standard,
      autoConnectOnStartup: true,
    );

    expect(updated.autoStartPrivilege, AppAutoStartPrivilege.standard);
    expect(updated.autoConnectOnStartup, isTrue);
    // Непереданные поля не трогаются.
    expect(updated.autoStartShowWindow, isFalse);
    expect(updated.autoConnectMode, ConnectionMode.proxy);
  });

  group('showNotifications (трек 25)', () {
    test('defaults to true', () {
      const settings = AppSettings();
      expect(settings.showNotifications, isTrue);
    });

    test('round-trips false through JSON', () {
      const settings = AppSettings(showNotifications: false);
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.showNotifications, isFalse);
    });

    test('missing key defaults to true (back-compat for existing settings.json)', () {
      final settings = AppSettings.fromJson({});
      expect(settings.showNotifications, isTrue);
    });
  });
}
