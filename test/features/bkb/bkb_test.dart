import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flux/features/bkb/bkb_controller.dart';
import 'package:flux/features/bkb/bkb_effect.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

void main() {
  testWidgets('maximizes for eight seconds then restores original bounds', (
    tester,
  ) async {
    const bounds = Rect.fromLTWH(100, 80, 960, 620);
    final calls = <String>[];
    Rect? restored;
    final bkb = BkbController(
      desktop: true,
      isMaximized: () async => false,
      getBounds: () async => bounds,
      maximize: () async {
        calls.add('maximize');
      },
      unmaximize: () async {
        calls.add('unmaximize');
      },
      setBounds: (rect) async {
        restored = rect;
        calls.add('restore');
      },
    );
    addTearDown(bkb.dispose);
    expect(await bkb.activate(), isTrue);
    expect(bkb.active, isTrue);
    await tester.pump(const Duration(seconds: 7));
    expect(bkb.active, isTrue);
    expect(bkb.remainingSeconds, 1);
    await bkb.activate(); // Repeated clicks cannot extend the timer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(bkb.active, isFalse);
    expect(bkb.restoreFailed, isFalse);
    expect(calls, ['maximize', 'unmaximize', 'restore']);
    expect(restored, bounds);
  });

  testWidgets('already maximized window remains maximized after BKB', (
    tester,
  ) async {
    var maximizations = 0;
    final bkb = BkbController(
      desktop: true,
      isMaximized: () async => true,
      getBounds: () async =>
          throw StateError('must not capture maximized bounds'),
      maximize: () async {
        maximizations++;
      },
      unmaximize: () async => throw StateError('must not unmaximize'),
    );
    addTearDown(bkb.dispose);
    await bkb.activate();
    await tester.pump(const Duration(seconds: 8));
    expect(maximizations, 2);
    expect(bkb.active, isFalse);
  });

  testWidgets('restoration failure still releases the golden effect', (
    tester,
  ) async {
    final bkb = BkbController(
      desktop: true,
      isMaximized: () async => false,
      getBounds: () async => const Rect.fromLTWH(0, 0, 960, 620),
      maximize: () async {},
      unmaximize: () async => throw StateError('OS error'),
    );
    addTearDown(bkb.dispose);
    await bkb.activate();
    await tester.pump(const Duration(seconds: 8));
    expect(bkb.restoreFailed, isTrue);
    expect(bkb.active, isFalse);
    expect(bkb.busy, isFalse);
  });

  testWidgets('golden effect expires with countdown and no off button', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final bkb = BkbController(desktop: false);
    addTearDown(bkb.dispose);
    await tester.pumpWidget(
      PortApp(
        builder: (context, child) => BkbEffect(controller: bkb, child: child),
        home: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    );
    await bkb.activate();
    await tester.pumpAndSettle();
    expect(find.text(S.bkbRemaining(8)), findsOneWidget);
    expect(find.byType(PortButton), findsNothing);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text(S.bkbRemaining(1)), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(bkb.active, isFalse);
    expect(find.text(S.bkbRemaining(1)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
