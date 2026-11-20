import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../app/app_paths.dart';
import 'habit.dart';

class HabitStore {
  Future<File> _file() async {
    final directory = Platform.isWindows
        ? Directory(fluxDataDirectoryPath())
        : await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/habits.json');
  }

  Future<List<Habit>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data
        .map((item) => Habit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Habit> habits) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(habits.map((h) => h.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
