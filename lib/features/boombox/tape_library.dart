import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_paths.dart';

class Tape {
  final String id;
  final String title;
  final String path;
  const Tape({required this.id, required this.title, required this.path});
}

class TapeLibrary {
  final Directory? directory;
  TapeLibrary({this.directory});

  Future<Directory> _root() async {
    final root =
        directory ??
        Directory(
          '${Platform.isWindows ? fluxDataDirectoryPath() : (await getApplicationSupportDirectory()).path}/tapes',
        );
    await root.create(recursive: true);
    return root;
  }

  Future<List<Tape>> load() async {
    final root = await _root();
    final tapes = <Tape>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final audio = File('${entry.path}/audio.mp3');
      final title = File('${entry.path}/title.txt');
      if (!await audio.exists() || !await title.exists()) continue;
      tapes.add(
        Tape(
          id: entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
          title: await title.readAsString(),
          path: audio.path,
        ),
      );
    }
    tapes.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return tapes;
  }

  Future<Tape> importMp3(String sourcePath) async {
    if (!sourcePath.toLowerCase().endsWith('.mp3')) {
      throw const FormatException('Expected MP3');
    }
    final source = File(sourcePath);
    if (await source.length() == 0) throw const FormatException('Empty MP3');
    final root = await _root();
    final id = const Uuid().v4();
    final folder = Directory('${root.path}/$id');
    await folder.create();
    final title = source.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.mp3$', caseSensitive: false),
      '',
    );
    final copy = await source.copy('${folder.path}/audio.part');
    await copy.rename('${folder.path}/audio.mp3');
    // The title commits the import: interrupted copies never appear on the shelf.
    await File('${folder.path}/title.txt').writeAsString(title, flush: true);
    return Tape(id: id, title: title, path: '${folder.path}/audio.mp3');
  }
}
