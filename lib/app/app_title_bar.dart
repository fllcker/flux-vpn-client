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
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _maximized = value);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: PortColors.background,
        border: Border(bottom: BorderSide(color: PortColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icon.png',
                      width: 20,
                      height: 20,
                      color: PortColors.foreground,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const SizedBox(width: 8),
                    Text('Flux', style: PortText.small),
                  ],
                ),
              ),
            ),
          ),
          _TitleBarButton(
            icon: widget.settingsOpen ? LucideIcons.x : LucideIcons.settings,
            iconSize: 13,
            active: widget.settingsOpen,
            onPressed: widget.onToggleSettings,
          ),
          _TitleBarButton(
            icon: LucideIcons.minus,
            onPressed: () => windowManager.minimize(),
          ),
          _TitleBarButton(
            icon: _maximized ? LucideIcons.copy : LucideIcons.square,
            iconSize: _maximized ? 13 : 12,
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
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color? hoverColor;
  final bool active;
  final VoidCallback onPressed;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 14,
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
          height: 40,
          color: background,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
        ),
      ),
    );
  }
}
