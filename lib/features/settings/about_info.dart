import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../engines/singbox/singbox_engine_macos.dart';
import '../../engines/singbox/singbox_engine_windows.dart';
import '../../engines/xray/xray_engine_macos.dart';
import '../../engines/xray/xray_engine_windows.dart';

/// Версии приложения и ядер — то, что первым делом спрашивают при разборе
/// проблемы («на чём воспроизводится?»).
class AboutInfo {
  final String appVersion;
  final String buildNumber;

  /// Дата сборки берётся из времени изменения самого .exe: отдельного
  /// build-таймстампа Flutter не прокидывает, а гадать по версии нельзя —
  /// одна и та же версия пересобирается десятки раз за вечер.
  final DateTime? builtAt;

  /// `null` — бинарник не найден или не запустился; UI показывает это как
  /// «не найден», а не как пустую строку, иначе отсутствующее ядро выглядит
  /// как «версия просто не определилась».
  final String? xrayVersion;
  final String? singBoxVersion;

  const AboutInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.builtAt,
    required this.xrayVersion,
    required this.singBoxVersion,
  });
}

/// Опрашивается лениво, при открытии настроек: это два запуска процессов, и
/// делать их на старте приложения ради экрана, куда заходят раз в месяц, незачем.
final aboutInfoProvider = FutureProvider<AboutInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();

  DateTime? builtAt;
  try {
    builtAt = File(Platform.resolvedExecutable).lastModifiedSync();
  } on FileSystemException {
    builtAt = null;
  }

  final versions = await Future.wait([
    _coreVersion(
      Platform.isMacOS
          ? defaultMacosXrayExecutablePath()
          : defaultXrayExecutablePath(),
    ),
    _coreVersion(
      Platform.isMacOS
          ? defaultMacosSingBoxExecutablePath()
          : defaultSingBoxExecutablePath(),
    ),
  ]);

  return AboutInfo(
    appVersion: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
    builtAt: builtAt,
    xrayVersion: versions[0],
    singBoxVersion: versions[1],
  );
});

Future<String?> _coreVersion(String executablePath) async {
  try {
    final result = await Process.run(executablePath, ['version']);
    if (result.exitCode != 0) return null;
    return parseCoreVersion(result.stdout as String);
  } on ProcessException {
    return null;
  }
}

/// Вытаскивает номер версии из первой строки вывода `<ядро> version`.
///
/// Форматы у ядер разные, и ловиться на этом не хочется:
///
/// * sing-box: `sing-box version 1.13.14`
/// * xray:     `Xray 26.3.27 (Xray, Penetrates Everything.) d2758a0 (go1.26.1 ...)`
///
/// То есть по ключевому слову `version` парсить нельзя — у xray его нет вовсе.
/// Берём первое, что похоже на номер версии: у xray это `26.3.27`, и он стоит
/// раньше версии Go из той же строки, которая иначе бы и подхватилась.
String? parseCoreVersion(String output) {
  final firstLine = output
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return null;
  return RegExp(r'\d+\.\d+(?:\.\d+)?').firstMatch(firstLine)?.group(0);
}
