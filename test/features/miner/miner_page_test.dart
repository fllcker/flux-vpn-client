import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flux/features/miner/miner_game.dart';
import 'package:flux/features/miner/miner_page.dart';
import 'package:flux/features/miner/miner_store.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

class _Store extends MinerStore {
  final game = MinerGame.fresh(seed: 12);
  Map<String, dynamic>? saved;
  bool fail = false;
  _Store() {
    game.tiles[game.index(7, 1)] = MineTile.coal;
  }
  @override
  Future<MinerGame?> load() async => game;
  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    if (fail) throw StateError('Disk error');
    saved = snapshot;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'keyboard mines ore, lift returns home and selling persists coins',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(PortApp(home: MinerPage(store: store)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(store.game.cargo[MineTile.coal], 1);
      expect(store.game.y, 1);
      await tester.ensureVisible(find.text(S.minerSurface));
      await tester.tap(find.text(S.minerSurface));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.minerSell(5)));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.game.coins, 5);
      expect(store.saved!['coins'], 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow screen supports touch mining and save failure keeps game open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store()..fail = true;
      await tester.pumpWidget(
        PortApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, animation, secondaryAnimation) =>
                      MinerPage(store: store),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip(S.minerDown));
      await tester.tap(find.byTooltip(S.minerDown));
      await tester.pumpAndSettle();
      expect(store.game.damage, isNotEmpty);
      await tester.scrollUntilVisible(
        find.byTooltip(S.flashlightClose),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip(S.flashlightClose));
      await tester.pumpAndSettle();
      expect(find.byType(MinerPage), findsOneWidget);
      expect(find.text(S.minerSaveError), findsOneWidget);
      store.fail = false;
      await tester.tap(find.byTooltip(S.flashlightClose));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(store.saved, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
