import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_server.dart';

final selectedServerIdProvider =
    NotifierProvider<SelectedServerIdController, String>(
      SelectedServerIdController.new,
    );

class SelectedServerIdController extends Notifier<String> {
  @override
  String build() => fakeServers.first.id;

  void select(String id) => state = id;
}
