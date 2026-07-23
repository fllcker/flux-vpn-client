import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedServerIdProvider =
    NotifierProvider<SelectedServerIdController, String?>(
      SelectedServerIdController.new,
    );

class SelectedServerIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}
