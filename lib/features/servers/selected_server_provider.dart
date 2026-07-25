import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core_abstraction/app_settings_provider.dart';
import '../../core_abstraction/core_config_provider.dart';
import 'flatten_leaves.dart';

final selectedServerIdProvider =
    NotifierProvider<SelectedServerIdController, String?>(
      SelectedServerIdController.new,
    );

/// Восстанавливает выбор сервера между запусками из `AppSettings.
/// lastSelectedServerId` (ROADMAP.md, трек 9) — предпочтение конкретной
/// машины, не часть Magic JSON-профиля. Id обязателен к проверке на
/// существование в текущем дереве при каждом построении: сервер мог
/// исчезнуть (удалили из подписки, снесли подписку целиком, рефреш
/// пересобрал дерево) — тогда возвращаем `null`, и потребители проваливаются
/// на свой обычный фолбэк "первый лист дерева" (`connect_panel.dart`,
/// `connection_screen.dart`, `server_list_panel.dart`, `tray.dart`).
class SelectedServerIdController extends Notifier<String?> {
  @override
  String? build() {
    final savedId = ref.watch(appSettingsProvider).lastSelectedServerId;
    if (savedId == null) return null;
    final exists = flattenAllLeaves(
      ref.watch(coreConfigProvider),
    ).any((leaf) => leaf.id == savedId);
    return exists ? savedId : null;
  }

  void select(String id) {
    state = id;
    ref
        .read(appSettingsProvider.notifier)
        .update((s) => s.copyWith(lastSelectedServerId: id));
  }
}
