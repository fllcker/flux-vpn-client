import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// `IsUserAnAdmin` не сгенерирован в package:win32 (числится устаревшим в
/// MSDN), но остаётся простейшим надёжным способом проверить, что ИМЕННО
/// текущий процесс сейчас запущен с повышенными правами (учитывает
/// split-token UAC, не просто членство в группе Administrators).
typedef _IsUserAnAdminNative = Int32 Function();
typedef _IsUserAnAdminDart = int Function();

final _isUserAnAdmin = DynamicLibrary.open(
  'shell32.dll',
).lookupFunction<_IsUserAnAdminNative, _IsUserAnAdminDart>('IsUserAnAdmin');

bool isRunningElevated() => _isUserAnAdmin() != 0;

/// Перезапускает текущий .exe с запросом прав администратора через UAC
/// (verb "runas") — как в Happ: пользователь подтверждает один раз при
/// включении TUN. Не завершает текущий процесс — это решает вызывающий
/// код после успешного запуска новой копии.
///
/// Возвращает `false`, если пользователь отклонил UAC-запрос или запуск не
/// удался.
bool relaunchElevated() {
  final filePtr = Platform.resolvedExecutable.toNativeUtf16();
  final operationPtr = 'runas'.toNativeUtf16();
  try {
    final instance = ShellExecute(
      null,
      PCWSTR(operationPtr),
      PCWSTR(filePtr),
      null,
      null,
      SW_SHOWNORMAL,
    );
    // По документации ShellExecute — значение > 32 означает успех.
    return instance.address > 32;
  } finally {
    calloc.free(filePtr);
    calloc.free(operationPtr);
  }
}
