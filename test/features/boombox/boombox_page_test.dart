import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flux/features/boombox/boombox_page.dart';
import 'package:flux/features/boombox/tape_library.dart';
import 'package:flux/features/boombox/tape_player.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

const _tape = Tape(id: 'one', title: 'Ночной маршрут', path: '/track.mp3');

class _Library extends TapeLibrary {
  @override
  Future<List<Tape>> load() async => [_tape];
}

class _Audio extends TapeAudio {
  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(minutes: 3);
  @override
  String? get error => null;
  String? loaded;
  bool fail = false;
  @override
  Future<void> load(String path) async {
    if (fail) throw Exception('bad MP3');
    loaded = path;
  }

  @override
  Future<void> play() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> unload() async {
    loaded = null;
    playing = false;
    notifyListeners();
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('drag cassette into deck, pause, and drag it back to shelf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _Audio();
    await tester.pumpWidget(
      PortApp(
        home: BoomboxPage(library: _Library(), audio: audio),
      ),
    );
    await tester.pumpAndSettle();
    final cassette = find.byType(Draggable<Tape>);
    await tester.dragFrom(
      tester.getCenter(cassette),
      tester.getCenter(find.byKey(const ValueKey('cassette-deck'))) -
          tester.getCenter(cassette),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(audio.loaded, _tape.path);
    expect(audio.playing, isTrue);
    await tester.tap(find.byTooltip(S.tapePause).last);
    await tester.pumpAndSettle();
    expect(audio.playing, isFalse);
    final inserted = find.byType(Draggable<Tape>);
    await tester.dragFrom(
      tester.getCenter(inserted),
      tester.getCenter(find.byKey(const ValueKey('cassette-shelf'))) -
          tester.getCenter(inserted),
    );
    await tester.pumpAndSettle();
    expect(audio.loaded, isNull);
    expect(find.text(S.tapeEmptyDeck), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout can eject a cassette that failed to load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _Audio()..fail = true;
    await tester.pumpWidget(
      PortApp(
        home: BoomboxPage(library: _Library(), audio: audio),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Draggable<Tape>));
    await tester.tap(find.byType(Draggable<Tape>));
    await tester.pumpAndSettle();
    expect(find.text(S.tapePlaybackError), findsOneWidget);
    await tester.ensureVisible(find.byTooltip(S.tapeEject).last);
    await tester.tap(find.byTooltip(S.tapeEject).last);
    await tester.pumpAndSettle();
    expect(find.byType(Draggable<Tape>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop preview', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: PortApp(
          home: BoomboxPage(library: _Library(), audio: _Audio()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('BOOMBOX_PREVIEW')) {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build').create(recursive: true);
        await File(
          'build/boombox-preview.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
