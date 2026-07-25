part of 'port_ui.dart';

/// Текущая эффективная яркость темы — читается статически из [PortColors]
/// геттеров вместо `Theme.of(context)`, чтобы не протаскивать context через
/// весь `port_ui`. Обновляется в `main.dart` (`_FluxAppState.build`) при
/// каждой перестройке корня приложения — после смены настройки темы или
/// смены системной темы ОС (см. `WidgetsBindingObserver.didChangePlatformBrightness`).
class PortBrightness {
  static Brightness current = Brightness.dark;
}
