import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Копия видеофайла, выбранного юзером под `HomeBackground.customVideo`
/// (`AppSettings.customVideoPath`) — кроссплатформенно, через
/// `path_provider`, а не `app_paths.dart` (тот хардкодит %APPDATA%, работает
/// только на Windows). Храним копию, а не оригинальный путь: юзер мог
/// выбрать файл со съёмного диска/временной папки, который может исчезнуть
/// или к которому на Android нет постоянного доступа без copy.
Future<String> importCustomVideo(String sourcePath) async {
  final supportDir = await getApplicationSupportDirectory();
  final videoDir = Directory('${supportDir.path}/backgrounds');
  await videoDir.create(recursive: true);

  // Старая копия могла быть с другим расширением — чистим каталог перед
  // копированием новой, а не просто перезаписываем: неиспользуемый файл
  // иначе остаётся на диске навсегда.
  if (await videoDir.exists()) {
    await for (final entity in videoDir.list()) {
      if (entity is File) await entity.delete();
    }
  }

  final dotIndex = sourcePath.lastIndexOf('.');
  final ext = dotIndex >= 0 ? sourcePath.substring(dotIndex) : '';
  final destPath = '${videoDir.path}/custom_video$ext';
  await File(sourcePath).copy(destPath);
  return destPath;
}

/// Убирает сохранённую копию — вызывается, когда юзер снимает видеофон.
Future<void> deleteCustomVideo(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
