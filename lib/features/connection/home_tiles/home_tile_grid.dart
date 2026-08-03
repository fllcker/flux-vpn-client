import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core_abstraction/app_settings_provider.dart';
import '../../../core_abstraction/connection_session.dart';
import '../../../core_abstraction/core_config_provider.dart';
import '../../../core_abstraction/home_tile_config.dart';
import '../../../core_abstraction/proxy_node.dart';
import '../../../core_abstraction/routing_preset.dart';
import '../../../l10n/strings.dart';
import '../../../widgets/port_ui/port_ui.dart';
import '../connection_state.dart';
import '../off_proxy_tun_selector.dart';
import 'home_tile_card.dart';
import 'home_tile_content.dart';

const _columns = homeTileColumns;
const _baseHeight = 52.0;
const _gap = 8.0;

ConnectSelection _modeSelection(ConnectionUiState state) => switch (state) {
  ConnectionConnected(mode: ConnectionMode.proxy) => ConnectSelection.proxy,
  ConnectionConnected(mode: ConnectionMode.tun) => ConnectSelection.tun,
  _ => ConnectSelection.off,
};

int _colSpan(HomeTileSize size) => switch (size) {
  HomeTileSize.small => 1,
  HomeTileSize.wide => 2,
  HomeTileSize.large => 3,
};

/// Проверяет, что ни одна плитка не выходит за правую границу ряда и что
/// никакие две плитки не занимают одну и ту же ячейку — вызывается перед
/// каждым сохранением новой раскладки (drag, ресайз), недопустимый
/// результат просто отбрасывается (drop/resize становится no-op), а не
/// молча портит раскладку.
bool _isValidArrangement(List<HomeTileConfig> tiles) {
  final occupied = <int>{};
  for (final t in tiles) {
    final span = _colSpan(t.size);
    final col = t.position % _columns;
    if (t.position < 0 || col + span > _columns) return false;
    for (var i = 0; i < span; i++) {
      if (!occupied.add(t.position + i)) return false;
    }
  }
  return true;
}

/// Первая свободная позиция, куда помещается плитка шириной [span] колонок,
/// не пересекая правую границу ряда — используется при добавлении новой
/// плитки кнопкой "+ Добавить".
int _firstFreePosition(List<HomeTileConfig> tiles, int span) {
  final occupied = <int>{};
  for (final t in tiles) {
    final s = _colSpan(t.size);
    for (var i = 0; i < s; i++) {
      occupied.add(t.position + i);
    }
  }
  var pos = 0;
  while (true) {
    final col = pos % _columns;
    if (col + span <= _columns) {
      var fits = true;
      for (var i = 0; i < span; i++) {
        if (occupied.contains(pos + i)) {
          fits = false;
          break;
        }
      }
      if (fits) return pos;
    }
    pos++;
  }
}

/// Кастомизируемая сетка плиток главного экрана — заменяет собой прежние
/// жёстко закодированные карточку сервера и `OffProxyTunSelector` в
/// `connect_panel.dart`. Позиция плитки — явная ячейка
/// (`HomeTileConfig.position`) в сетке из [_columns] колонок, а не порядок в
/// списке: раскладка может оставлять пустые ячейки (пользователь может
/// намеренно расположить плитки не впритык друг к другу). Обычный режим —
/// просто раскладка; режим редактирования (кнопка в шапке) показывает
/// пустые ячейки как реальные drop-зоны (не декоративная подложка — в них
/// правда можно перетащить плитку), плюс меню настроек (⋯) на каждой
/// плитке.
class HomeTileGrid extends ConsumerStatefulWidget {
  final ServerLeaf? leaf;
  final ConnectionUiState connectionState;
  final bool busy;
  final ValueChanged<ConnectSelection> onModeChanged;
  // Тап по плиткам сервера (serverInfo/serverIcon/serverStatus) на мобильной
  // раскладке открывает тот же bottom sheet со списком серверов, что и
  // раньше открывала карточка сервера — см. `connect_panel.dart`. `null` на
  // десктопе (там боковая панель со списком уже всегда видна).
  final VoidCallback? onOpenServerList;

  const HomeTileGrid({
    super.key,
    required this.leaf,
    required this.connectionState,
    required this.busy,
    required this.onModeChanged,
    this.onOpenServerList,
  });

  @override
  ConsumerState<HomeTileGrid> createState() => _HomeTileGridState();
}

class _HomeTileGridState extends ConsumerState<HomeTileGrid> {
  bool _editing = false;
  bool _hovering = false;

  void _updateTiles(List<HomeTileConfig> Function(List<HomeTileConfig> tiles) transform) {
    ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(homeTiles: transform(s.homeTiles)));
  }

  bool _canPlaceAt(String draggedId, int pos) {
    final tiles = ref.read(appSettingsProvider).homeTiles;
    final dragged = tiles.where((t) => t.id == draggedId).firstOrNull;
    if (dragged == null) return false;
    final candidate = _withSnappedPosition(tiles, dragged, pos);
    return _isValidArrangement(candidate);
  }

  List<HomeTileConfig> _withSnappedPosition(List<HomeTileConfig> tiles, HomeTileConfig dragged, int pos) {
    final snapped = _snapToRowStart(pos, _colSpan(dragged.size));
    return [for (final t in tiles) t.id == dragged.id ? t.copyWith(position: snapped) : t];
  }

  /// Ужимает позицию так, чтобы плитка шириной [span] колонок помещалась в
  /// строку — раньше при переполнении всегда прыгало на начало строки (col
  /// 0), из-за чего drop в последнюю ячейку ряда (напр. col 2 из 3 для
  /// span 2) откатывался в первые две ячейки вместо ожидаемых последних
  /// двух. Клэмпим стартовую колонку к последней, где плитка ещё помещается
  /// (`_columns - span`), а не всегда к нулю.
  int _snapToRowStart(int pos, int span) {
    final row = pos ~/ _columns;
    final col = pos % _columns;
    final snappedCol = col.clamp(0, _columns - span);
    return row * _columns + snappedCol;
  }

  void _moveToPosition(String draggedId, int pos) {
    _updateTiles((tiles) {
      final dragged = tiles.where((t) => t.id == draggedId).firstOrNull;
      if (dragged == null) return tiles;
      final candidate = _withSnappedPosition(tiles, dragged, pos);
      return _isValidArrangement(candidate) ? candidate : tiles;
    });
  }

  void _swapPositions(String aId, String bId) {
    if (aId == bId) return;
    _updateTiles((tiles) {
      final a = tiles.where((t) => t.id == aId).firstOrNull;
      final b = tiles.where((t) => t.id == bId).firstOrNull;
      if (a == null || b == null) return tiles;
      final candidate = [
        for (final t in tiles)
          t.id == aId ? t.copyWith(position: b.position) : (t.id == bId ? t.copyWith(position: a.position) : t),
      ];
      return _isValidArrangement(candidate) ? candidate : tiles;
    });
  }

  void _setSize(String id, HomeTileSize size) {
    _updateTiles((tiles) {
      final tile = tiles.where((t) => t.id == id).firstOrNull;
      if (tile == null) return tiles;
      final newPos = _snapToRowStart(tile.position, _colSpan(size));
      final candidate = [for (final t in tiles) t.id == id ? t.copyWith(size: size, position: newPos) : t];
      return _isValidArrangement(candidate) ? candidate : tiles;
    });
  }

  void _setRadius(String id, HomeTileRadiusStyle style) {
    _updateTiles((tiles) => [for (final t in tiles) t.id == id ? t.copyWith(radiusStyle: style) : t]);
  }

  void _setAlign(String id, HomeTileContentAlign align) {
    _updateTiles((tiles) => [for (final t in tiles) t.id == id ? t.copyWith(contentAlign: align) : t]);
  }

  void _remove(String id) {
    _updateTiles((tiles) => tiles.where((t) => t.id != id).toList());
  }

  void _add(HomeTileType type) {
    _updateTiles((tiles) {
      final span = _colSpan(type.supportedSizes.first);
      final pos = _firstFreePosition(tiles, span);
      return [...tiles, HomeTileConfig.create(type, position: pos)];
    });
  }

  void _openRoutingPresetMenu(Offset globalPosition, List<RoutingPreset> presets, String? activeId) {
    showPortContextMenu(
      context: context,
      globalPosition: globalPosition,
      items: [
        PortContextMenuItem(
          leading: activeId == null ? const Icon(LucideIcons.check, size: 14) : null,
          child: Text(S.serverRoutingPreset),
          onPressed: () =>
              ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(clearActiveRoutingPresetId: true)),
        ),
        for (final preset in presets)
          PortContextMenuItem(
            leading: activeId == preset.id ? const Icon(LucideIcons.check, size: 14) : null,
            child: Text(preset.name),
            onPressed: () =>
                ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(activeRoutingPresetId: preset.id)),
          ),
      ],
    );
  }

  void _openModeMenu(Offset globalPosition, ConnectSelection selection) {
    final simplified = Platform.isAndroid;
    showPortContextMenu(
      context: context,
      globalPosition: globalPosition,
      items: [
        PortContextMenuItem(
          leading: selection == ConnectSelection.off ? const Icon(LucideIcons.check, size: 14) : null,
          child: const Text('Off'),
          onPressed: () => widget.onModeChanged(ConnectSelection.off),
        ),
        if (!simplified)
          PortContextMenuItem(
            leading: selection == ConnectSelection.proxy ? const Icon(LucideIcons.check, size: 14) : null,
            child: const Text('Proxy'),
            onPressed: () => widget.onModeChanged(ConnectSelection.proxy),
          ),
        PortContextMenuItem(
          leading: selection == ConnectSelection.tun ? const Icon(LucideIcons.check, size: 14) : null,
          child: Text(simplified ? 'On' : 'TUN'),
          onPressed: () => widget.onModeChanged(ConnectSelection.tun),
        ),
      ],
    );
  }

  void _openVariantMenu(Offset globalPosition, ServerLeaf leaf) {
    showPortContextMenu(
      context: context,
      globalPosition: globalPosition,
      items: [
        for (final variant in leaf.variants)
          PortContextMenuItem(
            leading: leaf.activeVariant?.id == variant.id ? const Icon(LucideIcons.check, size: 14) : null,
            child: Text(variant.label),
            onPressed: () => ref.read(coreConfigProvider.notifier).selectVariant(leaf.id, variant.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final tiles = settings.homeTiles;
    final routingPresets = ref.watch(coreConfigProvider).routingPresets;
    final activeRoutingPresetId = settings.activeRoutingPresetId;

    final byPosition = {for (final t in tiles) t.position: t};
    final covered = <int>{};
    for (final t in tiles) {
      for (var i = 1; i < _colSpan(t.size); i++) {
        covered.add(t.position + i);
      }
    }
    final maxRow = tiles.isEmpty
        ? -1
        : tiles.map((t) => (t.position + _colSpan(t.size) - 1) ~/ _columns).reduce(max);
    // В режиме редактирования сетка всегда видна целиком — минимум
    // [_columns]x[_columns] (3x3) ячеек, даже если плиток меньше, иначе
    // некуда перетащить что-то на ещё не существующий ряд. Растёт дальше,
    // если плиток фактически больше.
    final numRows = _editing ? max(_columns, maxRow + 2) : maxRow + 1;

    // Вне редактирования колонки, которых ни одна плитка нигде не касается
    // (по всей раскладке, не построчно — напр. каждая строка занимает
    // только первые две из трёх колонок), не резервируют место: раньше
    // пустая колонка всё равно оставалась `Expanded(flex: 1)` пустого места,
    // и вся раскладка визуально съезжала от центра. minCol/maxCol — реально
    // используемый диапазон колонок; сетка рендерится только в его пределах
    // и центрируется в исходной ширине. В режиме редактирования диапазон
    // всегда полный — там пустые ячейки должны быть видны и доступны для
    // drop, а не схлопываться.
    final usedCols = <int>{};
    for (final t in tiles) {
      final col = t.position % _columns;
      for (var i = 0; i < _colSpan(t.size); i++) {
        usedCols.add(col + i);
      }
    }
    final minCol = _editing || usedCols.isEmpty ? 0 : usedCols.reduce(min);
    final maxCol = _editing || usedCols.isEmpty ? _columns - 1 : usedCols.reduce(max);
    final visibleColumns = maxCol - minCol + 1;

    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < numRows; row++) ...[
          _buildRow(row, byPosition, covered, routingPresets, activeRoutingPresetId, minCol, maxCol),
          const SizedBox(height: _gap),
        ],
        if (_editing) _AddTileRow(onAdd: _add),
      ],
    );

    final header = Align(
      alignment: Alignment.centerRight,
      // Кнопка не мешает виду, пока курсор вне области плиток — на
      // тач-платформах (нет ховера в принципе) видна всегда, иначе
      // редактирование было бы недостижимо. Пока идёт редактирование, видна
      // всегда независимо от ховера — "Готово" должно быть легко найти, не
      // подводя курсор точно под неё.
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _editing || _hovering || Platform.isAndroid || Platform.isIOS ? 1 : 0,
        child: IgnorePointer(
          ignoring: !(_editing || _hovering || Platform.isAndroid || Platform.isIOS),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Только в режиме редактирования — сброс раскладки вне его
              // контекста ничего не значит и рискует случайным нажатием.
              if (_editing) ...[
                PortButton.outline(
                  onPressed: () => _updateTiles((_) => List.of(defaultHomeTiles)),
                  child: Text(S.resetTilesToDefault),
                ),
                const SizedBox(width: 8),
              ],
              PortButton.outline(
                onPressed: () => setState(() => _editing = !_editing),
                child: Text(_editing ? S.doneCustomizingTiles : S.customizeTiles),
              ),
            ],
          ),
        ),
      ),
    );

    // Кнопка "Настроить"/"Готово" выровнена по правому краю здесь же, в этом
    // же Column — иначе при схлопывании неиспользуемых колонок (см. выше)
    // она осталась бы прижата к правому краю ИСХОДНОЙ (полной) ширины, а не
    // фактически видимой, более узкой раскладки, и визуально "оторвалась"
    // бы от плиток под ней.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const SizedBox(height: 8), rows],
    );

    final body = visibleColumns == _columns
        ? content
        : LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = (constraints.maxWidth - (_columns - 1) * _gap) / _columns;
              final visibleWidth = visibleColumns * columnWidth + (visibleColumns - 1) * _gap;
              // `heightFactor: 1` is load-bearing — plain `Align` expands to
              // fill all available height by default (bounded constraints
              // from the ancestor `Align(bottomCenter)` in `connect_panel.dart`
              // let it do exactly that), which broke that ancestor's
              // bottom-positioning: it now saw a child that already claimed
              // the whole available height, so "bottom" stopped meaning
              // anything and the actual content floated to the top of that
              // inflated box. Pinning height to the child's own height keeps
              // this Align purely a horizontal-centering wrapper.
              return Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: SizedBox(width: visibleWidth, child: content),
              );
            },
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: body,
    );
  }

  Widget _buildRow(
    int row,
    Map<int, HomeTileConfig> byPosition,
    Set<int> covered,
    List<RoutingPreset> routingPresets,
    String? activeRoutingPresetId,
    int minCol,
    int maxCol,
  ) {
    final slots = <Widget>[];
    for (var col = minCol; col <= maxCol; col++) {
      final pos = row * _columns + col;
      if (covered.contains(pos)) continue;
      if (slots.isNotEmpty) slots.add(const SizedBox(width: _gap));
      final tile = byPosition[pos];
      slots.add(
        tile != null
            ? Expanded(flex: _colSpan(tile.size), child: _buildTile(tile, routingPresets, activeRoutingPresetId))
            : Expanded(flex: 1, child: _buildEmptyCell(pos)),
      );
    }
    return SizedBox(height: _baseHeight, child: Row(children: slots));
  }

  Widget _buildEmptyCell(int pos) {
    if (!_editing) return const SizedBox.shrink();
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _canPlaceAt(details.data, pos),
      onAcceptWithDetails: (details) => _moveToPosition(details.data, pos),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        // Пустая ячейка должна быть видна сама по себе, не только когда над
        // ней что-то тащат — но в состоянии покоя достаточно едва заметной
        // подложки (не такой контрастной, как настоящие плитки: пустая
        // ячейка не должна бросаться в глаза сильнее самих плиток), а вот
        // hover-подсветка (что-то тащат прямо сюда) остаётся яркой — это
        // уже активная обратная связь, а не декоративный фон.
        //
        // Явные `width`/`height: double.infinity` тут обязательны — без них
        // это был настоящий баг, а не только вопрос альфы: голый
        // `DecoratedBox` без `child` в `Row` с дефолтным
        // `CrossAxisAlignment.center` получает свободные (loose)
        // ограничения по высоте и сжимается в 0×0 (`Expanded` растягивает
        // только по главной оси, не по кросс-оси) — ячейка была не только
        // невидимой, а буквально нулевого размера, поэтому и `DragTarget`
        // никогда не мог получить в неё drop. `HomeTileCard` этот баг не
        // ловит — там `Container` внутри уже задаёт `double.infinity` сам.
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: hovering ? PortColors.primary.withValues(alpha: 0.4) : PortColors.muted.withValues(alpha: 0.35),
            border: Border.all(
              color: hovering ? PortColors.primary : PortColors.mutedForeground.withValues(alpha: 0.4),
              width: hovering ? 1.5 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }

  Widget _buildTile(HomeTileConfig tile, List<RoutingPreset> routingPresets, String? activeRoutingPresetId) {
    final leaf = widget.leaf;
    final content = buildHomeTileContent(
      tile,
      leaf: leaf,
      connectionState: widget.connectionState,
      busy: widget.busy,
      onModeChanged: widget.onModeChanged,
      routingPresetLabel: activeRoutingPresetId == null
          ? S.serverRoutingPreset
          : _presetName(routingPresets, activeRoutingPresetId),
      variantLabel: leaf?.activeVariant?.label ?? '—',
      variantEnabled: (leaf?.variants.length ?? 0) > 1,
    );

    void Function(Offset)? onTap;
    if (!_editing) {
      switch (tile.type) {
        case HomeTileType.serverInfo:
        case HomeTileType.serverIcon:
        case HomeTileType.serverStatus:
          final open = widget.onOpenServerList;
          onTap = open == null ? null : (_) => open();
        case HomeTileType.modeSelector:
          // `small` не помещает сегменты — тап открывает то же меню
          // Off/Proxy/TUN отдельным попапом. На wide/large сегменты внутри
          // плитки сами обрабатывают тап, тут ничего не делаем.
          onTap = (tile.size == HomeTileSize.small && !widget.busy)
              ? (pos) => _openModeMenu(pos, _modeSelection(widget.connectionState))
              : null;
        case HomeTileType.routingPreset:
          onTap = (pos) => _openRoutingPresetMenu(pos, routingPresets, activeRoutingPresetId);
        case HomeTileType.variantSelector:
          onTap = (leaf == null || leaf.variants.length <= 1) ? null : (pos) => _openVariantMenu(pos, leaf);
      }
    }

    // Кнопка "Настроить" видна на тач-платформах и так (не завязана на
    // ховер там), но долгий тап по любой плитке — привычный
    // дополнительный вход в редактирование раскладки на телефоне (тот же
    // паттерн, что и у самого перетаскивания там — см. `LongPressDraggable`
    // ниже).
    final onLongPress = (!_editing && (Platform.isAndroid || Platform.isIOS))
        ? () {
            HapticFeedback.mediumImpact();
            setState(() => _editing = true);
          }
        : null;

    final card = HomeTileCard(
      radiusStyle: tile.radiusStyle,
      contentAlign: tile.contentAlign,
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );

    if (!_editing) return card;

    // `card`'s own `onTap` is already null in edit mode (see the switch
    // above), but that only covers the tap `HomeTileGrid` attaches itself —
    // some tile content is interactive on its own regardless of edit mode
    // (`OffProxyTunSelector`'s segment buttons for `modeSelector`, see
    // `home_tile_content.dart`). Left live, its `GestureDetector`s compete
    // with `Draggable`'s recognizer for the same pointer and can eat the
    // drag before it starts.
    //
    // `AbsorbPointer`, not `IgnorePointer`: `Draggable` listens for the
    // pointer via a `Listener` whose default hit-test behavior defers to its
    // child — `IgnorePointer` makes that child (and everything below it)
    // report "not hit" at all, so the `Listener` never sees the pointer down
    // either and dragging stops working entirely (confirmed — that's
    // exactly what broke just now). `AbsorbPointer` still reports a hit for
    // itself (so the ancestor `Listener`/`Draggable` gets the event) while
    // preventing the swallowed event from reaching interactive descendants.
    final inertCard = AbsorbPointer(child: card);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != tile.id,
      onAcceptWithDetails: (details) => _swapPositions(details.data, tile.id),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final stacked = Stack(
          children: [
            Opacity(opacity: hovering ? 0.6 : 1, child: inertCard),
            Positioned(
              top: 2,
              right: 2,
              child: PortContextMenuButton(items: _tileMenuItems(tile), size: 24),
            ),
          ],
        );

        if (Platform.isAndroid || Platform.isIOS) {
          return LongPressDraggable<String>(
            data: tile.id,
            feedback: _DragFeedback(tile: tile),
            childWhenDragging: Opacity(opacity: 0.4, child: inertCard),
            child: stacked,
          );
        }

        return Draggable<String>(
          data: tile.id,
          feedback: _DragFeedback(tile: tile),
          childWhenDragging: Opacity(opacity: 0.4, child: inertCard),
          child: stacked,
        );
      },
    );
  }

  /// Меню настроек одной плитки — сгруппировано подменю (Ширина/Скругление/
  /// Расположение), а не один плоский список вперемешку, как было раньше.
  List<PortContextMenuItem> _tileMenuItems(HomeTileConfig tile) {
    return [
      PortContextMenuItem(
        child: Text(S.tileWidthLabel),
        submenu: [
          for (final size in tile.type.supportedSizes)
            PortContextMenuItem(
              leading: tile.size == size ? const Icon(LucideIcons.check, size: 14) : null,
              child: Text(_sizeLabel(size)),
              onPressed: () => _setSize(tile.id, size),
            ),
        ],
      ),
      PortContextMenuItem(
        child: Text(S.tileRadiusStyleLabel),
        submenu: [
          for (final style in HomeTileRadiusStyle.values)
            PortContextMenuItem(
              leading: tile.radiusStyle == style ? const Icon(LucideIcons.check, size: 14) : null,
              child: Text(_radiusLabel(style)),
              onPressed: () => _setRadius(tile.id, style),
            ),
        ],
      ),
      if (tile.type.supportsContentAlign)
        PortContextMenuItem(
          child: Text(S.tileAlignLabel),
          submenu: [
            for (final align in HomeTileContentAlign.values)
              PortContextMenuItem(
                leading: tile.contentAlign == align ? const Icon(LucideIcons.check, size: 14) : null,
                child: Text(_alignLabel(align)),
                onPressed: () => _setAlign(tile.id, align),
              ),
          ],
        ),
      PortContextMenuItem(
        leading: const Icon(LucideIcons.trash2, size: 14),
        destructive: true,
        child: Text(S.removeTile),
        onPressed: () => _remove(tile.id),
      ),
    ];
  }
}

String _sizeLabel(HomeTileSize size) => switch (size) {
  HomeTileSize.small => S.tileSizeSmall,
  HomeTileSize.wide => S.tileSizeWide,
  HomeTileSize.large => S.tileSizeLarge,
};

String _radiusLabel(HomeTileRadiusStyle style) => switch (style) {
  HomeTileRadiusStyle.sharp => S.tileRadiusSharp,
  HomeTileRadiusStyle.rounded => S.tileRadiusRounded,
  HomeTileRadiusStyle.pill => S.tileRadiusPill,
};

String _alignLabel(HomeTileContentAlign align) => switch (align) {
  HomeTileContentAlign.start => S.tileAlignStart,
  HomeTileContentAlign.center => S.tileAlignCenter,
  HomeTileContentAlign.end => S.tileAlignEnd,
};

String tileTypeLabel(HomeTileType type) => switch (type) {
  HomeTileType.serverInfo => S.tileTypeServerInfo,
  HomeTileType.serverIcon => S.tileTypeServerIcon,
  HomeTileType.serverStatus => S.tileTypeServerStatus,
  HomeTileType.modeSelector => S.tileTypeModeSelector,
  HomeTileType.routingPreset => S.tileTypeRoutingPreset,
  HomeTileType.variantSelector => S.tileTypeVariantSelector,
};

String _presetName(List<RoutingPreset> presets, String id) {
  for (final preset in presets) {
    if (preset.id == id) return preset.name;
  }
  return S.serverRoutingPreset;
}

/// Кнопка "+ Добавить" в конце сетки в режиме редактирования — тап
/// открывает список типов плиток (см. [HomeTileType]) тем же контекстным
/// меню, что и остальные пикеры (позиция — точка тапа, см.
/// `showPortContextMenu`), без ограничения на уникальность: можно добавить
/// `serverIcon`+`serverStatus` рядом вместо одной совмещённой `serverInfo` —
/// это и есть механизм "разбить плитку на две" из запроса. Новая плитка
/// встаёт в первую подходящую по ширине свободную ячейку (`_firstFreePosition`),
/// не обязательно в конец списка — с явными позициями это уже не одно и то
/// же.
class _AddTileRow extends StatelessWidget {
  final ValueChanged<HomeTileType> onAdd;
  const _AddTileRow({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _baseHeight,
      child: GestureDetector(
        onTapUp: (details) => showPortContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          items: [
            for (final type in HomeTileType.values)
              PortContextMenuItem(child: Text(tileTypeLabel(type)), onPressed: () => onAdd(type)),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: PortColors.inputBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 16, color: PortColors.foreground),
                const SizedBox(width: 8),
                Text(S.addTile, style: PortText.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final HomeTileConfig tile;
  const _DragFeedback({required this.tile});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: _baseHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PortColors.popover,
          borderRadius: BorderRadius.circular(radiusForStyle(tile.radiusStyle)),
          border: Border.all(color: PortColors.border),
          boxShadow: [
            BoxShadow(color: PortColors.primary.withValues(alpha: 0.2), blurRadius: 12),
          ],
        ),
        child: Center(
          child: Text(tileTypeLabel(tile.type), style: PortText.small, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
