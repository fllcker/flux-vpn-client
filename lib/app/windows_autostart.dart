import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:win32_registry/win32_registry.dart';

import '../core_abstraction/app_settings.dart';

/// Автозапуск при старте Windows — обычный (`standard`) через реестровый
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (не требует прав
/// администратора), либо `elevated` — через Scheduled Task с "Run with
/// highest privileges" (`_taskName`). Реестровый `Run` физически не может
/// элевейтить процесс без интерактивного UAC на каждый вход в систему —
/// Scheduled Task с этим флагом умеет исполняться от полного admin-токена
/// без диалога при каждом входе, но саму задачу можно создать только из
/// уже elevated-процесса, поэтому создание задачи тут само идёт через
/// `ShellExecute` с verb `"runas"` (тот же приём, что и
/// `windows_elevation.dart`'s `relaunchElevated()`, но нацеленный на
/// `schtasks.exe`, а не на весь `flux.exe` — не перезапускает всё
/// приложение только ради регистрации автозапуска). См. ROADMAP.md, трек 24.
const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _runValueName = 'Flux';
const _taskName = 'Flux';

/// Настраивает автозапуск согласно [privilege]/[showWindow] — синхронно с
/// изменением одноимённых полей `AppSettings` (см. `settings_page.dart`).
/// Всегда сначала чистит оба механизма (реестр + scheduled task), чтобы не
/// оставлять "хвост" от предыдущего выбора при переключении между
/// `standard`/`elevated`.
///
/// `elevated`-ветка не ждёт завершения `schtasks.exe` (ShellExecute это не
/// умеет без отдельного `ShellExecuteEx` + wait-handle, усложнять не
/// стали) — вызывающая сторона должна сама проверить результат позже через
/// [isElevatedAutoStartActuallyRegistered] (пользователь мог отклонить
/// UAC-запрос).
void setAutoStartOnBoot({
  required AppAutoStartPrivilege privilege,
  required bool showWindow,
}) {
  if (!Platform.isWindows) return;

  _removeRegistryRun();
  _removeScheduledTask();

  switch (privilege) {
    case AppAutoStartPrivilege.none:
      return;
    case AppAutoStartPrivilege.standard:
      _writeRegistryRun(showWindow: showWindow);
    case AppAutoStartPrivilege.elevated:
      _createScheduledTaskElevated(showWindow: showWindow);
  }
}

void _writeRegistryRun({required bool showWindow}) {
  final key = CURRENT_USER.create(_runKeyPath);
  final exePath = Platform.resolvedExecutable;
  final command = showWindow ? '"$exePath"' : '"$exePath" --minimized';
  key.setValue(_runValueName, RegistryValue.string(command));
}

void _removeRegistryRun() {
  try {
    CURRENT_USER.create(_runKeyPath).removeValue(_runValueName);
  } catch (_) {
    // Значения не было — уже выключено, ничего делать не нужно.
  }
}

void _createScheduledTaskElevated({required bool showWindow}) {
  final exePath = Platform.resolvedExecutable;
  // Экранирование по стандартным правилам CRT-парсинга командной строки:
  // /tr должен получить единым аргументом `"<exePath>" [--minimized]`,
  // поэтому внутренние кавычки экранируются как `\"` — задокументированная
  // рабочая форма для schtasks /tr с путём, содержащим пробелы.
  final trValue = '\\"$exePath\\"${showWindow ? '' : ' --minimized'}';
  final parameters =
      '/create /tn "$_taskName" /tr "$trValue" /sc onlogon /rl highest /f';
  _shellExecuteRunAs('schtasks.exe', parameters);
}

void _removeScheduledTask() {
  try {
    Process.runSync('schtasks.exe', ['/delete', '/tn', _taskName, '/f']);
  } catch (_) {
    // Задачи не было — не ошибка.
  }
}

/// Проверяет, реально ли зарегистрирована elevated-задача автозапуска —
/// сам запрос не требует прав администратора (только создание с `/rl
/// highest` требует). Используется настройками, чтобы показать
/// пользователю тост об успехе/неудаче после [setAutoStartOnBoot]
/// (`ShellExecute` не сообщает результат синхронно — пользователь мог
/// отклонить UAC).
Future<bool> isElevatedAutoStartActuallyRegistered() async {
  if (!Platform.isWindows) return false;
  try {
    final result = await Process.run('schtasks.exe', ['/query', '/tn', _taskName]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// `ShellExecute` с verb `"runas"` — запрашивает UAC один раз на конкретную
/// команду, не перезапуская весь процесс приложения (в отличие от
/// `windows_elevation.dart`'s `relaunchElevated()`, которая релончит сам
/// `flux.exe`). Не ждёт завершения запущенного процесса.
bool _shellExecuteRunAs(String file, String parameters) {
  final filePtr = file.toNativeUtf16();
  final operationPtr = 'runas'.toNativeUtf16();
  final parametersPtr = parameters.toNativeUtf16();
  try {
    final instance = ShellExecute(
      null,
      PCWSTR(operationPtr),
      PCWSTR(filePtr),
      PCWSTR(parametersPtr),
      null,
      SW_HIDE,
    );
    // По документации ShellExecute — значение > 32 означает успех.
    return instance.address > 32;
  } finally {
    calloc.free(filePtr);
    calloc.free(operationPtr);
    calloc.free(parametersPtr);
  }
}
