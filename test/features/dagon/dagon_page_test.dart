import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flux/features/dagon/dagon_page.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

void main() {
  testWidgets('all five levels show their bundled icon on a narrow screen', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PortApp(home: DagonPage()));
    for (var level = 1; level <= 5; level++) {
      await tester.ensureVisible(find.widgetWithText(PortButton, '$level'));
      await tester.tap(find.widgetWithText(PortButton, '$level'));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/rofl/dagon_$level.png',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
