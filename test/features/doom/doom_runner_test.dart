import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/doom/doom_runner.dart';

Uint8List _wad({String magic = 'IWAD', String map = 'E1M1'}) {
  final bytes = Uint8List(28);
  bytes.setRange(0, 4, ascii.encode(magic));
  final header = ByteData.sublistView(bytes);
  header.setInt32(4, 1, Endian.little);
  header.setInt32(8, 12, Endian.little);
  bytes.setRange(20, 20 + map.length, ascii.encode(map));
  return bytes;
}

void main() {
  test(
    'accepts Doom and Doom II IWADs, rejects mods and corrupt tables',
    () async {
      final root = await Directory.systemTemp.createTemp('flux-doom-test-');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/test.wad');
      for (final map in ['E1M1', 'MAP01']) {
        await file.writeAsBytes(_wad(map: map));
        await validateDoomIwad(file);
      }
      await file.writeAsBytes(_wad(magic: 'PWAD'));
      await expectLater(validateDoomIwad(file), throwsFormatException);
      await file.writeAsBytes(_wad(map: 'NOTAMAP'));
      await expectLater(validateDoomIwad(file), throwsFormatException);
      final corrupt = _wad();
      ByteData.sublistView(corrupt).setInt32(8, 9999999, Endian.little);
      await file.writeAsBytes(corrupt);
      await expectLater(validateDoomIwad(file), throwsFormatException);
    },
  );

  test(
    'custom IWAD is copied and restored without the original file',
    () async {
      final root = await Directory.systemTemp.createTemp('flux-doom-test-');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/Мой DOOM.wad');
      await source.writeAsBytes(_wad());
      final data = Directory('${root.path}/data');
      final runner = DoomRunner(dataOverride: data);
      addTearDown(runner.dispose);
      await runner.importWad(source.path);
      await source.delete();
      final restored = DoomRunner(
        dataOverride: data,
        runtimeOverride: Directory('${root.path}/missing'),
      );
      addTearDown(restored.dispose);
      await restored.refresh();
      expect(restored.customTitle, 'Мой DOOM.wad');
      expect(restored.available, isFalse);
      expect(restored.running, isFalse);
    },
  );

  test('launch arguments preserve paths with spaces and isolate saves', () {
    final args = doomArguments(
      wadPath: 'C:/My games/DOOM.wad',
      dataPath: 'C:/User data/doom',
    );
    expect(args[args.indexOf('-iwad') + 1], 'C:/My games/DOOM.wad');
    expect(args[args.indexOf('-savedir') + 1], 'C:/User data/doom');
    expect(args, contains('-window'));
    expect(args[args.indexOf('-config') + 1], 'C:/User data/doom/default.cfg');
  });

  test(
    'bundled Freedoom has a valid IWAD directory',
    () async {
      await validateDoomIwad(File('assets/doom/freedoom1.wad'));
    },
    skip: !File('assets/doom/freedoom1.wad').existsSync(),
  );
}
