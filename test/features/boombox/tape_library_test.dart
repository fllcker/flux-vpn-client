import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/boombox/tape_library.dart';

void main() {
  test(
    'imports keep independent copies and restore titles after restart',
    () async {
      final root = await Directory.systemTemp.createTemp('flux-tape-test-');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/Мой трек.MP3');
      await source.writeAsBytes([73, 68, 51, 1, 2, 3]);
      final directory = Directory('${root.path}/library');
      final library = TapeLibrary(directory: directory);
      final first = await library.importMp3(source.path);
      final second = await library.importMp3(source.path);
      await source.delete();
      final restored = await TapeLibrary(directory: directory).load();
      expect(restored.map((t) => t.title), ['Мой трек', 'Мой трек']);
      expect(first.id, isNot(second.id));
      expect(await File(first.path).readAsBytes(), [73, 68, 51, 1, 2, 3]);
    },
  );

  test('invalid input and incomplete imports never become cassettes', () async {
    final root = await Directory.systemTemp.createTemp('flux-tape-test-');
    addTearDown(() => root.delete(recursive: true));
    final library = TapeLibrary(directory: Directory('${root.path}/library'));
    final empty = await File('${root.path}/empty.mp3').create();
    await expectLater(library.importMp3(empty.path), throwsFormatException);
    await expectLater(
      library.importMp3('${root.path}/other.txt'),
      throwsFormatException,
    );
    final incomplete = await Directory(
      '${root.path}/library/incomplete',
    ).create(recursive: true);
    await File('${incomplete.path}/audio.part').writeAsBytes([1]);
    expect(await library.load(), isEmpty);
  });
}
