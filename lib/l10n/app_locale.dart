import '../core_abstraction/app_settings.dart';

/// Эффективный (не `system`) язык интерфейса — обновляется в `main.dart`
/// (`_FluxAppState.build`) при каждой перестройке корня: либо прямое
/// значение из настроек, либо резолв `AppLanguage.system` в `ru`/`en` по
/// локали ОС. `S` (см. `strings.dart`) читает это статически, без context,
/// по аналогии с `PortBrightness` (см. `widgets/port_ui/port_theme.dart`).
class AppLocale {
  static AppLanguage effective = AppLanguage.ru;
}
