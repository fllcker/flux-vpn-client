import 'package:flutter/widgets.dart';

/// Ширина окна, ниже которой включается мобильная раскладка (см.
/// ROADMAP.md, трек 16). Единственная реальная платформа сейчас — Windows,
/// брейкпоинт проверяется через resize окна вручную, а не через
/// определение платформы; когда появится настоящий мобильный таргет,
/// разделение "нет тайтлбара" должно идти по платформе, а не по этому
/// порогу — см. заметку в ROADMAP.md про `AppTitleBar`.
const kMobileBreakpoint = 560.0;

bool isMobileLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kMobileBreakpoint;
