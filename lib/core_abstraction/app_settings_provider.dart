import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'app_settings_storage.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => appSettingsStorage.load();

  void update(AppSettings Function(AppSettings settings) transform) {
    state = transform(state);
    appSettingsStorage.save(state);
  }
}
