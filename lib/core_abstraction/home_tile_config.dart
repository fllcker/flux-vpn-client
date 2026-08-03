import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Ширина сетки в колонках (см. `home_tile_grid.dart`) — общая константа тут,
/// а не только в UI-слое, т.к. модель (валидные позиции/переполнение ряда)
/// от неё тоже зависит.
const homeTileColumns = 3;

/// Тип плитки на главном экране (см. `features/connection/home_tiles/home_tile_grid.dart`).
/// `serverInfo` — совмещённая иконка+имя+статус (вид "как раньше");
/// `serverIcon`/`serverStatus` — та же информация, разбитая на две отдельные
/// плитки для более гибкой раскладки.
enum HomeTileType {
  serverInfo,
  serverIcon,
  serverStatus,
  modeSelector,
  routingPreset,
  variantSelector,
}

/// Size-класс плитки — доля ширины в трёхколоночной сетке (`small` = 1/3,
/// `wide` = 2/3, `large` = 3/3), высота всех рядов одинаковая (без отдельной
/// "двойной высоты" — только ширина, как и просили). Дискретные варианты,
/// как на iOS, а не свободный pixel-resize (см. план).
enum HomeTileSize { small, wide, large }

/// Пресет скругления плитки — заменяет собой прежнюю жёсткую привязку к
/// `Platform.isAndroid` (999 на Android, 10 на десктопе) в `connect_panel.dart`
/// и `off_proxy_tun_selector.dart`: теперь это независимая ручная настройка
/// каждой плитки на любой платформе.
enum HomeTileRadiusStyle { sharp, rounded, pill }

/// Выравнивание содержимого внутри плитки — по умолчанию `start` (как было
/// всегда: иконка/текст у левого края). Влияет только на горизонтальную ось;
/// по вертикали содержимое всегда центрируется (см. `HomeTileCard`) — раньше
/// это было багом (контент прилипал к верху при доп. пустой высоте ряда), а
/// не сознательным поведением.
enum HomeTileContentAlign { start, center, end }

extension HomeTileTypeSizes on HomeTileType {
  /// Какие size-классы допустимы для этого типа плитки — например,
  /// `modeSelector` (Off/Proxy/TUN) не помещается в `small`, а
  /// `serverIcon` не имеет смысла шире `small`.
  List<HomeTileSize> get supportedSizes => switch (this) {
    HomeTileType.serverIcon => const [HomeTileSize.small],
    // `small` — компактный вид (просто текущий режим текстом), тап
    // открывает то же самое меню Off/Proxy/TUN, что обычно доступно как
    // сегменты — см. `home_tile_grid.dart`, `_openModeMenu`.
    HomeTileType.modeSelector => const [
      HomeTileSize.small,
      HomeTileSize.wide,
      HomeTileSize.large,
    ],
    // `small` — компактный вид (иконка+имя без статуса), чтобы рядом в том
    // же ряду помещалась ещё плитка.
    HomeTileType.serverInfo => const [
      HomeTileSize.small,
      HomeTileSize.wide,
      HomeTileSize.large,
    ],
    HomeTileType.serverStatus => const [HomeTileSize.small, HomeTileSize.wide],
    HomeTileType.routingPreset ||
    HomeTileType.variantSelector => const [
      HomeTileSize.small,
      HomeTileSize.wide,
      HomeTileSize.large,
    ],
  };

  /// `modeSelector` — сегменты и так растягиваются на всю ширину плитки
  /// (см. `OffProxyTunSelector`), настройка выравнивания на него визуально
  /// не влияет, поэтому не показываем её в диалоге настроек плитки.
  bool get supportsContentAlign => this != HomeTileType.modeSelector;
}

class HomeTileConfig {
  final String id;
  final HomeTileType type;
  final HomeTileSize size;
  final HomeTileRadiusStyle radiusStyle;
  final HomeTileContentAlign contentAlign;

  /// Индекс первой (левой верхней) ячейки плитки в сетке из
  /// [homeTileColumns] колонок, построчно слева направо, начиная с 0 — не
  /// порядковый номер в списке. Явные позиции (а не просто порядок в
  /// списке) — намеренно: без них модель не могла оставлять пустые ячейки
  /// (пользователь просил такую возможность), любая перестановка сразу
  /// "уплотняла" всё вплотную.
  final int position;

  const HomeTileConfig({
    required this.id,
    required this.type,
    required this.size,
    required this.position,
    this.radiusStyle = HomeTileRadiusStyle.rounded,
    this.contentAlign = HomeTileContentAlign.start,
  });

  /// Новая плитка при добавлении из "+ Добавить" — id через uuid (в отличие
  /// от id дефолтных плиток, см. [defaultHomeTiles], не может быть const).
  /// [position] вычисляет вызывающая сторона (первая свободная ячейка,
  /// подходящая по ширине — см. `home_tile_grid.dart`, `_firstFreePosition`).
  factory HomeTileConfig.create(HomeTileType type, {required int position}) => HomeTileConfig(
    id: _uuid.v4(),
    type: type,
    size: type.supportedSizes.first,
    position: position,
  );

  factory HomeTileConfig.fromJson(Map<String, dynamic> json) {
    final type = HomeTileType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => HomeTileType.serverInfo,
    );
    return HomeTileConfig(
      id: json['id'] as String,
      type: type,
      size: HomeTileSize.values.firstWhere(
        (s) => s.name == json['size'],
        orElse: () => type.supportedSizes.first,
      ),
      position: json['position'] as int? ?? 0,
      radiusStyle: HomeTileRadiusStyle.values.firstWhere(
        (r) => r.name == json['radiusStyle'],
        orElse: () => HomeTileRadiusStyle.rounded,
      ),
      contentAlign: HomeTileContentAlign.values.firstWhere(
        (a) => a.name == json['contentAlign'],
        orElse: () => HomeTileContentAlign.start,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'size': size.name,
    'position': position,
    'radiusStyle': radiusStyle.name,
    'contentAlign': contentAlign.name,
  };

  HomeTileConfig copyWith({
    HomeTileSize? size,
    HomeTileRadiusStyle? radiusStyle,
    HomeTileContentAlign? contentAlign,
    int? position,
  }) => HomeTileConfig(
    id: id,
    type: type,
    size: size ?? this.size,
    position: position ?? this.position,
    radiusStyle: radiusStyle ?? this.radiusStyle,
    contentAlign: contentAlign ?? this.contentAlign,
  );
}

/// Раскладка по умолчанию — карточка сервера и Off/Proxy/TUN, каждая на
/// 2/3 ширины (`wide`), со скруглением `pill`, друг под другом: `position`
/// 0 и 3 — начало первого и второго ряда. Третья колонка в обоих рядах
/// остаётся незанятой — раскладка так и задумана в этом виде, а не
/// "промежуточное" состояние (см. `home_tile_grid.dart`, центрирование по
/// фактически используемым колонкам вне режима редактирования). Id —
/// фиксированные строки, не uuid: это позволяет списку быть `const` (нужно
/// для дефолтного значения поля в `const`-конструкторе `AppSettings`, см.
/// `app_settings.dart`).
const List<HomeTileConfig> defaultHomeTiles = [
  HomeTileConfig(
    id: 'default-server-info',
    type: HomeTileType.serverInfo,
    size: HomeTileSize.wide,
    position: 0,
    radiusStyle: HomeTileRadiusStyle.pill,
  ),
  HomeTileConfig(
    id: 'default-mode-selector',
    type: HomeTileType.modeSelector,
    size: HomeTileSize.wide,
    position: homeTileColumns,
    radiusStyle: HomeTileRadiusStyle.pill,
  ),
];
