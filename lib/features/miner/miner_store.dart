import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../app/app_paths.dart';
import 'miner_game.dart';

class MinerStore {
  final Directory? directory;
  MinerStore({this.directory});
  Future<File> _file() async {
    final root =
        directory ??
        (Platform.isWindows
            ? Directory(fluxDataDirectoryPath())
            : await getApplicationSupportDirectory());
    await root.create(recursive: true);
    return File('${root.path}/miner.json');
  }

  Future<MinerGame?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return MinerGame.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> save(Map<String, dynamic> snapshot) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot), flush: true);
    await temporary.rename(file.path);
  }
}
