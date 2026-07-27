import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../app/app_paths.dart';
import '../core_abstraction/geo_dat_format.dart';

String geoipFilePath() => '${ensureFluxGeoDirectory()}\\geoip.dat';
String geositeFilePath() => '${ensureFluxGeoDirectory()}\\geosite.dat';

/// Докачивает `geoip.dat`/`geosite.dat`, если их ещё нет на диске —
/// вызывается при каждом старте приложения (не только "при первом запуске":
/// ручное удаление файла пользователем чинится тем же путём, без отдельного
/// состояния мастера первого запуска, см. ROADMAP.md трек 20). Best-effort:
/// сетевая ошибка не бросается наружу — приложение просто стартует без
/// geoip/geosite-роутинга, как и раньше было единственным поведением при
/// отсутствии этих файлов.
Future<void> ensureGeoAssets({
  required String geoipUrl,
  required String geositeUrl,
}) async {
  await Future.wait([
    _ensureFile(geoipFilePath(), geoipUrl, parseGeoIpDat),
    _ensureFile(geositeFilePath(), geositeUrl, parseGeoSiteDat),
  ]);
}

/// Принудительно перекачивает оба файла (кнопка "Обновить" в настройках) —
/// в отличие от [ensureGeoAssets], не проверяет существование заранее.
/// Ошибка сети/HTTP/парсинга пробрасывается наружу, чтобы UI мог показать
/// тост с причиной — здесь это явное пользовательское действие, а не
/// best-effort фон при старте.
Future<void> forceUpdateGeoAssets({
  required String geoipUrl,
  required String geositeUrl,
}) async {
  await Future.wait([
    _downloadTo(geoipFilePath(), geoipUrl, parseGeoIpDat),
    _downloadTo(geositeFilePath(), geositeUrl, parseGeoSiteDat),
  ]);
}

Future<void> _ensureFile(
  String path,
  String url,
  List<Object> Function(Uint8List) validate,
) async {
  if (File(path).existsSync()) return;
  try {
    await _downloadTo(path, url, validate);
  } catch (_) {
    // best-effort — см. doc-комментарий ensureGeoAssets
  }
}

/// Пишет во временный файл рядом и переименовывает поверх целевого —
/// обрыв соединения на середине скачивания не оставляет битый файл вместо
/// рабочего (старый, если был, остаётся нетронутым до успешного `rename`).
/// [validate] прогоняет скачанные байты через парсер из
/// `geo_dat_format.dart` перед заменой — битый/не тот формат файла не должен
/// молча стать новым "рабочим" geoip/geosite (ROADMAP.md, трек 20, п.11).
Future<void> _downloadTo(
  String path,
  String url,
  List<Object> Function(Uint8List) validate,
) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw HttpException(
      'HTTP ${response.statusCode} при скачивании $url',
      uri: Uri.parse(url),
    );
  }
  if (response.bodyBytes.isEmpty) {
    throw HttpException('Пустой ответ при скачивании $url', uri: Uri.parse(url));
  }
  validate(response.bodyBytes);
  final tmp = File('$path.tmp');
  await tmp.writeAsBytes(response.bodyBytes);
  await tmp.rename(path);
}
