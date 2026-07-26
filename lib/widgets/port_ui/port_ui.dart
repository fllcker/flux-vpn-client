/// Ручной 1:1 порт нужных нам компонентов shadcn/ui (см.
/// `docs/shadcn/PLAN.md` — методология, откуда взят каждый класс/токен,
/// известные ограничения). Заменяет пакет `shadcn_ui`.
///
/// Библиотека собрана через `part`/`part of` (не отдельные независимые
/// файлы) — компоненты активно шарят приватные хелперы (`_Interactive`,
/// `_kEase`, цвета) между собой, как было в исходной песочнице
/// `lib/dev/shadcn_playground.dart`, откуда этот код перенесён и расширен
/// под реальные нужды приложения (generic Select, Toast-контроллер,
/// ContextMenu с leading-иконками, Input с controller и т.п.).
///
/// Тёмная и светлая темы — см. `PortColors`/`PortBrightness`. Переключение
/// не через `Theme.of(context)`, а через глобальный статический флаг
/// `PortBrightness.current`, который обновляет `main.dart` при смене
/// `AppThemeMode`/системной темы ОС — так не пришлось протаскивать context
/// через весь `port_ui`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

part 'port_theme.dart';
part 'port_tokens.dart';
part 'port_button.dart';
part 'port_input.dart';
part 'port_switch.dart';
part 'port_select.dart';
part 'port_tabs.dart';
part 'port_dialog.dart';
part 'port_bottom_sheet.dart';
part 'port_context_menu.dart';
part 'port_toast.dart';
part 'port_app.dart';
