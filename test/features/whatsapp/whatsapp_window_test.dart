import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/whatsapp/whatsapp_window.dart';

class _Window implements Webview {
  int handle = 100;
  final closed = Completer<void>();
  final urls = <String>[];
  bool failLaunch = false;
  @override
  int get nativeWindowHandle => handle;
  @override
  Future<void> get onClose => closed.future;
  @override
  Future<void> launch(
    String url, {
    bool triggerOnUrlRequestEvent = true,
  }) async {
    if (failLaunch) throw StateError('Navigation failed');
    urls.add(url);
  }

  @override
  Future<void> close() async {
    handle = 0;
    if (!closed.isCompleted) closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory profile;
  setUp(() async {
    profile = await Directory.systemTemp.createTemp('flux-whatsapp-test-');
  });
  tearDown(() async {
    await profile.delete(recursive: true);
  });

  test(
    'opens official WhatsApp, reuses window, and preserves profile on reopen',
    () async {
      final windows = <_Window>[];
      final configurations = <CreateConfiguration>[];
      final focused = <int>[];
      final service = WhatsappWindow(
        supported: () => true,
        available: () async => true,
        profile: () async => profile,
        focus: focused.add,
        create: (config) async {
          configurations.add(config);
          final window = _Window();
          windows.add(window);
          return window;
        },
      );
      expect(await service.open(), WhatsappOpenResult.opened);
      expect(windows.single.urls, [whatsappWebUrl]);
      expect(await service.open(), WhatsappOpenResult.opened);
      expect(windows, hasLength(1));
      expect(focused, [100]);
      await File('${profile.path}/session-marker').writeAsString('keep');
      await windows.single.close();
      await service.open();
      expect(windows, hasLength(2));
      expect(configurations.map((c) => c.windows.userDataFolder).toSet(), {
        profile.absolute.path,
      });
      expect(
        await File('${profile.path}/session-marker').readAsString(),
        'keep',
      );
      await windows.last.close();
    },
  );

  test('rapid clicks share one pending native creation', () async {
    final creation = Completer<Webview>();
    var calls = 0;
    final window = _Window();
    final service = WhatsappWindow(
      supported: () => true,
      available: () async => true,
      profile: () async => profile,
      focus: (_) {},
      create: (_) {
        calls++;
        return creation.future;
      },
    );
    final first = service.open();
    final second = service.open();
    expect(identical(first, second), isTrue);
    creation.complete(window);
    expect(await first, WhatsappOpenResult.opened);
    expect(calls, 1);
    expect(service.opening, isFalse);
    await window.close();
  });

  test(
    'missing runtime and unsupported platform never create a window',
    () async {
      var calls = 0;
      Future<Webview> create(CreateConfiguration _) async {
        calls++;
        return _Window();
      }

      final missing = WhatsappWindow(
        supported: () => true,
        available: () async => false,
        create: create,
      );
      expect(await missing.open(), WhatsappOpenResult.runtimeMissing);
      final unsupported = WhatsappWindow(
        supported: () => false,
        create: create,
      );
      expect(await unsupported.open(), WhatsappOpenResult.unsupported);
      expect(calls, 0);
    },
  );

  test('failed navigation closes half-open window and allows retry', () async {
    final broken = _Window()..failLaunch = true;
    final healthy = _Window();
    var calls = 0;
    final service = WhatsappWindow(
      supported: () => true,
      available: () async => true,
      profile: () async => profile,
      focus: (_) {},
      create: (_) async => calls++ == 0 ? broken : healthy,
    );
    expect(await service.open(), WhatsappOpenResult.failed);
    expect(broken.handle, 0);
    expect(await service.open(), WhatsappOpenResult.opened);
    expect(healthy.urls, [whatsappWebUrl]);
    await healthy.close();
  });
}
