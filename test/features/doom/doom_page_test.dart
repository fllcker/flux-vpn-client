import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flux/features/doom/doom_page.dart';
import 'package:flux/features/doom/doom_runner.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

class _Runner extends DoomRunner {
  int launches = 0;
  bool selectedCustom = false;
  @override
  bool get supported => true;
  @override
  Future<void> refresh() async {
    available = true;
    customTitle = 'DOOM2.wad';
    notifyListeners();
  }

  @override
  Future<void> launch({bool custom = false}) async {
    launches++;
    selectedCustom = custom;
  }
}

void main() {
  testWidgets('narrow launcher selects own IWAD and only launches on click', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runner = _Runner();
    addTearDown(runner.dispose);
    await tester.pumpWidget(PortApp(home: DoomPage(runner: runner)));
    await tester.pumpAndSettle();
    expect(runner.launches, 0);
    await tester.tap(find.text('DOOM2.wad'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('launch-doom')));
    await tester.tap(find.byKey(const ValueKey('launch-doom')));
    await tester.pumpAndSettle();
    expect(runner.launches, 1);
    expect(runner.selectedCustom, isTrue);
    expect(find.text(S.doomWindowHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
