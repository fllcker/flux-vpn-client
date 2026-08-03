import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/port_ui/port_ui.dart';

/// Кастомный тайтлбар вместо системного — окно создаётся как frameless
/// (см. main.dart, `TitleBarStyle.hidden`), поэтому перетаскивание и
/// свёртывание/закрытие теперь целиком на нашей стороне.
class AppTitleBar extends StatefulWidget {
  final bool settingsOpen;
  final VoidCallback onToggleSettings;

  const AppTitleBar({
    super.key,
    required this.settingsOpen,
    required this.onToggleSettings,
  });

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows && !Platform.isMacOS) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _maximized = value);
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/icon.png',
      width: 20,
      height: 20,
      color: PortColors.foreground,
      colorBlendMode: BlendMode.srcIn,
    );

    // На macOS `TitleBarStyle.hidden` (main.dart) убирает только текст
    // заголовка — нативные traffic lights (закрыть/свернуть/развернуть)
    // остаются слева поверх окна. Рисовать там же свои лого/кнопки нельзя —
    // логотип сдвинут в центр, а свои min/max/close вообще не нужны, ими и
    // так управляют traffic lights.
    final titleRow = Platform.isMacOS
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              logo,
              const SizedBox(width: 8),
              Text('Flux', style: PortText.small),
            ],
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                logo,
                const SizedBox(width: 8),
                Text('Flux', style: PortText.small),
              ],
            ),
          );

    // Нативный macOS-тайтлбар с traffic lights — 28pt; 40 (Windows/прочее)
    // тут был бы непропорционально толстым по сравнению с самими traffic
    // lights (те же 28pt слева, см. SizedBox(width: 70) выше).
    final barHeight = Platform.isMacOS ? 28.0 : 40.0;

    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: PortColors.background,
        border: Border(bottom: BorderSide(color: PortColors.border)),
      ),
      child: Row(
        children: [
          // Ширина traffic lights в hidden-режиме — см. Apple HIG, тот же
          // отступ использует сам AppKit под системный трафлайт-кластер.
          if (Platform.isMacOS) const SizedBox(width: 70),
          // DragToMoveArea/minimize/maximize/close — окно с рамкой и
          // системными кнопками есть только на десктопе (см. main.dart,
          // `TitleBarStyle.hidden` — кастомный тайтлбар вместо системного).
          // На Android своя навигация (жест "назад"/системная панель),
          // window_manager там не зарегистрирован вообще.
          Expanded(
            child: (Platform.isWindows || Platform.isMacOS)
                ? DragToMoveArea(child: titleRow)
                : titleRow,
          ),
          _TitleBarButton(
            icon: widget.settingsOpen ? LucideIcons.x : LucideIcons.settings,
            iconSize: 13,
            height: barHeight,
            active: widget.settingsOpen,
            onPressed: widget.onToggleSettings,
          ),
          // Свои min/max/close нужны только на Windows — на macOS это уже
          // делают нативные traffic lights (см. выше).
          if (Platform.isWindows) ...[
            _TitleBarButton(
              icon: LucideIcons.minus,
              height: barHeight,
              onPressed: () => windowManager.minimize(),
            ),
            _TitleBarButton(
              icon: _maximized ? LucideIcons.copy : LucideIcons.square,
              iconSize: _maximized ? 13 : 12,
              height: barHeight,
              onPressed: () => windowManager.isMaximized().then((maximized) {
                if (maximized) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              }),
            ),
            _TitleBarButton(
              icon: LucideIcons.x,
              hoverColor: const Color(0xFFEF4444),
              onPressed: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final double height;
  final Color? hoverColor;
  final bool active;
  final VoidCallback onPressed;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 14,
    this.height = 40,
    this.hoverColor,
    this.active = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered || widget.active
        ? (widget.hoverColor ?? PortColors.accent)
        : const Color(0x00000000);
    final iconColor = _hovered && widget.hoverColor != null
        ? const Color(0xFFFFFFFF)
        : PortColors.foreground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: widget.height,
          color: background,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
        ),
      ),
    );
  }
}
