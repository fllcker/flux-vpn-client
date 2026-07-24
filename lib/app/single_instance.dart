import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Локальный loopback-порт, используемый только как IPC между экземплярами
/// Flux — выбран произвольно, но должен быть один и тот же в каждой сборке
/// (запись в реестр под `flux://` подразумевает, что ОС может запустить
/// второй процесс в любой момент, пока первый уже открыт).
const _singleInstancePort = 47812;

/// Результат попытки стать основным экземпляром приложения.
sealed class SingleInstanceResult {
  const SingleInstanceResult();
}

/// Этот процесс — единственный: держит слушателя порта и стрим диплинков,
/// присланных последующими (тут же завершающимися) запусками.
class PrimaryInstance extends SingleInstanceResult {
  final Stream<String> incomingDeepLinks;
  const PrimaryInstance(this.incomingDeepLinks);
}

/// Уже есть работающий экземпляр — этот процесс переслал ему диплинк (если
/// он был) и должен немедленно завершиться без инициализации Flutter UI.
class SecondaryInstance extends SingleInstanceResult {
  const SecondaryInstance();
}

/// Пытается занять единственный на приложение loopback-порт. Успех —
/// значит, мы первый (и единственный) экземпляр Flux, нужно продолжать
/// обычный запуск. Если порт занят — где-то уже работает другой экземпляр:
/// шлём ему диплинк (если он есть в [deepLink]) через тот же порт и
/// возвращаем [SecondaryInstance], чтобы вызывающий код тут же вызвал
/// `exit(0)`, не создавая второе окно.
Future<SingleInstanceResult> acquireSingleInstance({String? deepLink}) async {
  try {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _singleInstancePort,
    );
    final controller = StreamController<String>.broadcast();
    server.listen((socket) {
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.isNotEmpty) controller.add(line);
          });
    });
    return PrimaryInstance(controller.stream);
  } on SocketException {
    // Порт занят — уже есть основной экземпляр. Передаём ему диплинк и
    // выходим.
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _singleInstancePort,
        timeout: const Duration(seconds: 2),
      );
      socket.write('${deepLink ?? ''}\n');
      await socket.flush();
      await socket.close();
    } catch (_) {
      // Основной экземпляр не ответил (завис/закрывается) — всё равно не
      // открываем второе окно, просто молча выходим.
    }
    return const SecondaryInstance();
  }
}
