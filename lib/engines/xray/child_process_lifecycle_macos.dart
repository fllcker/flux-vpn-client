import 'dart:async';
import 'dart:io';

/// macOS-аналог `child_process_job.dart`'s `tieChildProcessLifetimeToApp` —
/// на Windows Job Object гарантирует, что ОС сама убьёт дочерний процесс,
/// если родитель умрёт по любой причине (в т.ч. крашем). На macOS нет
/// прямого эквивалента без привилегированного хелпера/launchd-supervision
/// (которых пока нет — см. TODO(dev-account) в `macos/Runner/*.entitlements`),
/// поэтому это best-effort: убиваем все зарегистрированные дочерние процессы
/// по SIGINT/SIGTERM самого приложения. Обычное отключение/выход всё равно
/// идёт через `stop()` у самого движка (см. `xray_engine_macos.dart`,
/// `singbox_engine_macos.dart`) — это только страховка на случай, если
/// процесс приложения получит сигнал раньше, чем успеет вызвать `stop()`.
/// Краш без сигнала (SIGKILL, kill -9) эта страховка не покрывает — как и
/// сам Job Object не покрывал бы SIGKILL, посланный самому Job Object
/// извне, так что это не регресс, а тот же класс риска.
final _trackedProcesses = <Process>{};
StreamSubscription<ProcessSignal>? _sigintSub;
StreamSubscription<ProcessSignal>? _sigtermSub;

void tieChildProcessLifetimeToApp(Process process) {
  _trackedProcesses.add(process);
  unawaited(process.exitCode.then((_) => _trackedProcesses.remove(process)));

  _sigintSub ??= ProcessSignal.sigint.watch().listen((_) => _killAllAndExit());
  _sigtermSub ??= ProcessSignal.sigterm.watch().listen(
    (_) => _killAllAndExit(),
  );
}

void _killAllAndExit() {
  for (final process in _trackedProcesses) {
    process.kill();
  }
  exit(0);
}
