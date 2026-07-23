import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/connection_session.dart';

/// Локальный UI-стейт для прототипа экрана — режим и статус тут не связаны
/// с реальным ConnectionController/XrayEngine, пока дизайн не согласован.
final connectionModeProvider =
    NotifierProvider<ConnectionModeController, ConnectionMode>(
      ConnectionModeController.new,
    );

class ConnectionModeController extends Notifier<ConnectionMode> {
  @override
  ConnectionMode build() => ConnectionMode.proxy;

  void select(ConnectionMode mode) => state = mode;
}

final fakeConnectedProvider =
    NotifierProvider<FakeConnectedController, bool>(
      FakeConnectedController.new,
    );

class FakeConnectedController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
