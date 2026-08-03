import 'package:flutter/widgets.dart';

import '../../../core_abstraction/home_tile_config.dart';
import '../../../widgets/port_ui/port_ui.dart';

double radiusForStyle(HomeTileRadiusStyle style) => switch (style) {
  HomeTileRadiusStyle.sharp => 6.0,
  HomeTileRadiusStyle.rounded => 14.0,
  // 999 гарантированно превышает половину высоты/ширины любой плитки —
  // Flutter сам клэмпит BorderRadius.circular до "stadium"-формы, тот же
  // приём, что раньше был жёстко привязан к Platform.isAndroid.
  HomeTileRadiusStyle.pill => 999.0,
};

Alignment alignmentFor(HomeTileContentAlign align) => switch (align) {
  // Вертикаль всегда по центру — раньше без явного alignment контент
  // прилипал к верху контейнера (баг, не задумывалось), см. doc-комментарий
  // [HomeTileContentAlign].
  HomeTileContentAlign.start => Alignment.centerLeft,
  HomeTileContentAlign.center => Alignment.center,
  HomeTileContentAlign.end => Alignment.centerRight,
};

/// Общий контейнер плитки — фон, скругление по [radiusStyle], выравнивание
/// содержимого по [contentAlign], опциональный тап (с ховером на десктопе —
/// плитка "кликабельна", это должно быть видно, даже когда управление
/// расположено внутри неё, как у переключателей роутинга/варианта). Заменяет
/// собой два независимых `Container`-а с дублирующейся логикой радиуса,
/// которые раньше были в `connect_panel.dart` и `off_proxy_tun_selector.dart`.
class HomeTileCard extends StatefulWidget {
  final Widget child;
  final HomeTileRadiusStyle radiusStyle;
  final HomeTileContentAlign contentAlign;
  final EdgeInsetsGeometry padding;
  // Позиция тапа (глобальные координаты) передаётся наружу, чтобы вызывающая
  // сторона могла открыть меню/попап ровно там, где тапнули — без отдельного
  // `context.findRenderObject()` у самой плитки.
  final void Function(Offset globalPosition)? onTap;
  // Долгий тап — на телефоне вход в режим редактирования плиток (см.
  // `home_tile_grid.dart`, `_buildTile`): кнопка "Настроить" там завязана на
  // ховер, которого на тач-экранах физически не бывает (см.
  // `Platform.isAndroid || Platform.isIOS` в её видимости — она и так видна
  // всегда там, но долгий тап по любой плитке даёт более естественный вход,
  // привычный по паттерну "зажми иконку, чтобы переставить" на телефонах).
  final VoidCallback? onLongPress;

  const HomeTileCard({
    super.key,
    required this.child,
    required this.radiusStyle,
    this.contentAlign = HomeTileContentAlign.start,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.onTap,
    this.onLongPress,
  });

  @override
  State<HomeTileCard> createState() => _HomeTileCardState();
}

class _HomeTileCardState extends State<HomeTileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final interactive = tappable || widget.onLongPress != null;
    final content = Container(
      width: double.infinity,
      height: double.infinity,
      padding: widget.padding,
      alignment: alignmentFor(widget.contentAlign),
      decoration: BoxDecoration(
        color: PortColors.muted.withValues(alpha: tappable && _hovered ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(radiusForStyle(widget.radiusStyle)),
      ),
      child: widget.child,
    );

    if (!interactive) return content;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapUp: widget.onTap == null ? null : (details) => widget.onTap!(details.globalPosition),
        onLongPress: widget.onLongPress,
        child: content,
      ),
    );
  }
}
