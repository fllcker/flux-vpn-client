import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/features/flashlight/flashlight_page.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

void main() {
  testWidgets('beam responds to gestures, power and screen mode', (
    tester,
  ) async {
    await tester.pumpWidget(const PortApp(home: FlashlightPage()));
    expect(find.byType(Slider), findsNWidgets(3));
    final before =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is CustomPaint && w.painter is FlashlightBeamPainter,
                  ),
                )
                .painter!
            as FlashlightBeamPainter;
    await tester.timedDrag(
      find.byKey(const ValueKey('beam-gesture')),
      const Offset(30, -30),
      const Duration(milliseconds: 400),
    );
    await tester.pump();
    final after =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is CustomPaint && w.painter is FlashlightBeamPainter,
                  ),
                )
                .painter!
            as FlashlightBeamPainter;
    expect(after.length, greaterThan(before.length));
    expect(after.width, greaterThan(before.width));

    await tester.ensureVisible(find.byKey(const ValueKey('flashlight-power')));
    await tester.tap(find.byKey(const ValueKey('flashlight-power')));
    await tester.pumpAndSettle();
    expect(find.text(S.flashlightOff), findsOneWidget);
    await tester.tap(find.text(S.flashlightScreen));
    await tester.pumpAndSettle();
    expect(find.text(S.flashlightBackToBeam), findsOneWidget);
    await tester.tap(find.text(S.flashlightBackToBeam));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.text(S.flashlightOff), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controls fit a narrow screen and page can be closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PortApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => openFlashlight(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(S.flashlightScreen));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byTooltip(S.flashlightClose),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip(S.flashlightClose));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
