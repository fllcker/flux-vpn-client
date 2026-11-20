import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_paths.dart';
import '../../engines/xray/child_process_job.dart';

/// Reject PWAD mods and broken directory tables before handing data to the engine.
Future<void> validateDoomIwad(File file) async {
  final handle = await file.open();
  try {
    final size = await handle.length();
    final header = await handle.read(12);
    if (header.length != 12 ||
        ascii.decode(header.sublist(0, 4), allowInvalid: true) != 'IWAD') {
      throw const FormatException('Select a complete Doom IWAD');
    }
    final bytes = ByteData.sublistView(header);
    final count = bytes.getInt32(4, Endian.little);
    final offset = bytes.getInt32(8, Endian.little);
    if (count <= 0 ||
        count > 100000 ||
        offset < 12 ||
        offset + count * 16 > size) {
      throw const FormatException('Invalid WAD directory');
    }
    await handle.setPosition(offset);
    final directory = await handle.read(count * 16);
    if (directory.length != count * 16) {
      throw const FormatException('Truncated directory');
    }
    var hasMap = false;
    final table = ByteData.sublistView(directory);
    for (var i = 0; i < count; i++) {
      final start = table.getInt32(i * 16, Endian.little);
      final length = table.getInt32(i * 16 + 4, Endian.little);
      if (start < 0 || length < 0 || start + length > size) {
        throw const FormatException('Invalid WAD lump');
      }
      final name = ascii
          .decode(
            directory.sublist(i * 16 + 8, i * 16 + 16),
            allowInvalid: true,
          )
          .replaceAll('\u0000', '');
      if (name == 'E1M1' || name == 'MAP01') hasMap = true;
    }
    if (!hasMap) throw const FormatException('No Doom starting map');
  } finally {
    await handle.close();
  }
}

List<String> doomArguments({
  required String wadPath,
  required String dataPath,
}) => [
  '-iwad',
  wadPath,
  '-window',
  '-width',
  '960',
  '-height',
  '600',
  '-config',
  '$dataPath/default.cfg',
  '-extraconfig',
  '$dataPath/crispy.cfg',
  '-savedir',
  dataPath,
];

class DoomRunner extends ChangeNotifier {
  static final instance = DoomRunner();
  final Directory? runtimeOverride;
  final Directory? dataOverride;
  DoomRunner({this.runtimeOverride, this.dataOverride});

  bool loading = false;
  bool starting = false;
  bool available = false;
  bool failed = false;
  bool get running => _process != null;
  bool get supported => Platform.isWindows;
  String? customTitle;
  String? _customId;
  Process? _process;
  Directory? _runtime;

  Directory get _data =>
      dataOverride ?? Directory('${fluxDataDirectoryPath()}/doom');

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final bundled = Directory(
        '${File(Platform.resolvedExecutable).parent.path}/assets/doom',
      );
      final development = Directory('${Directory.current.path}/assets/doom');
      _runtime =
          runtimeOverride ??
          (await File('${bundled.path}/crispy-doom.exe').exists()
              ? bundled
              : development);
      available =
          supported &&
          await File('${_runtime!.path}/crispy-doom.exe').exists() &&
          await File('${_runtime!.path}/freedoom1.wad').exists();
      final manifest = File('${_data.path}/selected.json');
      if (await manifest.exists()) {
        final value =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final id = value['id'] as String;
        if (RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) &&
            await File('${_data.path}/custom/$id/game.wad').exists()) {
          _customId = id;
          customTitle = value['title'] as String;
        }
      }
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> importWad(String sourcePath) async {
    if (running || starting) return;
    await validateDoomIwad(File(sourcePath));
    final id = const Uuid().v4();
    final folder = Directory('${_data.path}/custom/$id');
    await folder.create(recursive: true);
    await File(sourcePath).copy('${folder.path}/game.wad');
    final title = File(sourcePath).uri.pathSegments.last;
    final temporary = File('${_data.path}/selected.json.tmp');
    await temporary.writeAsString(
      jsonEncode({'id': id, 'title': title}),
      flush: true,
    );
    await temporary.rename('${_data.path}/selected.json');
    _customId = id;
    customTitle = title;
    notifyListeners();
  }

  Future<void> launch({bool custom = false}) async {
    if (running || starting || !available || !supported) return;
    starting = true;
    failed = false;
    notifyListeners();
    try {
      final id = custom ? _customId : null;
      if (custom && id == null) throw StateError('No custom WAD');
      final wad = custom
          ? '${_data.path}/custom/$id/game.wad'
          : '${_runtime!.path}/freedoom1.wad';
      final saves = Directory(
        '${_data.path}/saves/${custom ? id : 'freedoom'}',
      );
      await saves.create(recursive: true);
      final process = await Process.start(
        '${_runtime!.path}/crispy-doom.exe',
        doomArguments(wadPath: wad, dataPath: saves.path),
        workingDirectory: saves.path,
        runInShell: false,
      );
      _process = process;
      // Same app-lifetime policy as the bundled VPN engines.
      tieChildProcessLifetimeToApp(process);
      final log = File('${saves.path}/last-session.log').openWrite();
      final stdoutDone = process.stdout.listen(log.add).asFuture<void>();
      final stderrDone = process.stderr.listen(log.add).asFuture<void>();
      unawaited(_watch(process, log, stdoutDone, stderrDone));
    } catch (_) {
      failed = true;
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> _watch(
    Process process,
    IOSink log,
    Future<void> stdoutDone,
    Future<void> stderrDone,
  ) async {
    try {
      final code = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (code != 0) failed = true;
    } catch (_) {
      failed = true;
    } finally {
      try {
        await log.close();
      } catch (_) {
        failed = true;
      }
      if (identical(_process, process)) _process = null;
      notifyListeners();
    }
  }
}
