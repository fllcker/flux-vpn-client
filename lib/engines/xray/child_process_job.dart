import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows Job Object, к которому привязываются дочерние процессы движков
/// (xray.exe), с флагом JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE — ОС сама убьёт
/// их, если наше приложение завершится (в т.ч. крашем), а не оставит
/// висеть осиротевший xray.exe вместе с TUN-адаптером или включённым
/// системным прокси навсегда. Без этого дочерний процесс в Windows не
/// привязан к жизни родителя сам по себе.
const _jobObjectLimitKillOnJobClose = 0x2000;

/// sizeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION) на x64 — структура не
/// сгенерирована в package:win32, раскладка стабильна и задокументирована
/// Microsoft, поэтому просто пишем нужное поле (LimitFlags, смещение 16)
/// в заранее обнулённый буфер нужного размера.
const _jobObjectExtendedLimitInformationSize = 144;

HANDLE? _jobHandle;

HANDLE _ensureJobObject() {
  final existing = _jobHandle;
  if (existing != null) return existing;

  final job = CreateJobObject(null, null).value;

  final info = calloc<Uint8>(_jobObjectExtendedLimitInformationSize);
  try {
    (info + 16).cast<Uint32>().value = _jobObjectLimitKillOnJobClose;
    SetInformationJobObject(
      job,
      JobObjectExtendedLimitInformation,
      info,
      _jobObjectExtendedLimitInformationSize,
    );
  } finally {
    calloc.free(info);
  }

  _jobHandle = job;
  return job;
}

/// Привязывает уже запущенный дочерний процесс к job object приложения —
/// процесс будет принудительно завершён, если приложение закроется.
void tieChildProcessLifetimeToApp(Process process) {
  final job = _ensureJobObject();
  final processHandle = OpenProcess(
    PROCESS_ACCESS_RIGHTS(PROCESS_TERMINATE | PROCESS_SET_QUOTA),
    false,
    process.pid,
  ).value;
  AssignProcessToJobObject(job, processHandle);
}
