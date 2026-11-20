# Текущий контекст (для возобновления работы)

Две связанные задачи в работе. Обновляйте этот файл при возврате к теме —
он не для истории, а для быстрого "с чем мы тут" после паузы.

## 1. Плитки на главном экране — реализовано, не закоммичено

Кастомизируемая сетка плиток вместо жёстко закодированных карточки сервера
+ Off/Proxy/TUN. Все изменения в рабочей копии, ещё не закоммичены
(`git status` — новые/изменённые файлы под `lib/features/connection/`,
`lib/core_abstraction/home_tile_config.dart`, `lib/widgets/port_ui/
port_context_menu.dart` и др.).

**Что сделано, по итогам нескольких раундов правок от пользователя:**
- Модель: `lib/core_abstraction/home_tile_config.dart` — `HomeTileConfig`
  (id, type, size, position, radiusStyle, contentAlign), 6 типов плиток
  (serverInfo/serverIcon/serverStatus/modeSelector/routingPreset/
  variantSelector), сетка 3 колонки, `position` — явная ячейка (не порядок
  в списке), допускает пустые ячейки. Хранится в `AppSettings.homeTiles`.
- UI: `lib/features/connection/home_tiles/` — `HomeTileGrid` (раскладка +
  режим редактирования), `HomeTileCard` (общий контейнер, ховер,
  выравнивание), `home_tile_content.dart` (контент по типу плитки).
- Режим редактирования: кнопка "Настроить" видна по ховеру над плитками
  (на Android/iOS — всегда), сетка в edit-режиме всегда показывает минимум
  3×3 видимых ячеек (даже пустых — с заметной подложкой, не почти
  прозрачной рамкой, это было баг-фиксом), drag-n-drop с реальными
  drop-таргетами на пустые ячейки.
- Настройки плитки — сгруппированное контекстное меню (submenu на
  наведении, с fallback на тап для тач-устройств) вместо диалога: Ширина /
  Скругление / Расположение / Удалить. Реализовано в
  `lib/widgets/port_ui/port_context_menu.dart` (`PortContextMenuItem.submenu`,
  `_SubmenuController`) — общий переиспользуемый примитив, не только для
  плиток.
- `modeSelector` — есть компактный вариант `small` (текст текущего режима +
  тап открывает меню Off/Proxy/TUN), помимо обычных встроенных сегментов на
  wide/large.

**Не проверено руками** — весь интерактив (drag, submenu, ховер-появление
кнопки) собран и проходит `flutter analyze`/`flutter test`, но визуально в
приложении не гонялся (см. CLAUDE.md — сам это не тестирую).

**Следующий шаг, если продолжаем эту ветку:** закоммитить, попросить
пользователя погонять руками, доисправить по фидбеку.

## 2. Пресеты роутинга — 2.1 и 2.2 реализованы, НЕ закоммичены

Диалог создания/редактирования пресета
(`lib/features/servers/routing_rules_dialog.dart`).

### 2.1 Явное правило "Остальной трафик" — готово

`RoutingPreset.defaultOutboundTag` (`lib/core_abstraction/routing_preset.dart`,
дефолт `'proxy'` — поведение существующих пресетов не меняется молча).
Прокинуто **отдельным именованным параметром** через весь путь запуска
(не через `ServerLeaf`/`CoreConfig` — там ему делать нечего, поле есть
только у пресетов): `effectiveDefaultOutboundTag()`
(`lib/core_abstraction/effective_routing.dart`) → `CoreEngine.start(...,
defaultOutboundTag: ...)` → `XrayEngine*`/`SingBoxEngine*`/`TunBridgeEngine*`
→ мапперы. xray (`xray_config_mapper.dart`) — `_orderedOutbounds` переставляет
нужный outbound первым (xray берёт первый outbound как дефолт). sing-box
(`singbox_config_mapper.dart`) — `route.final` через `_finalOutboundTag`
(`proxy`→`xray-socks-out`, `direct`→`direct`, `block`→ добавленный
`{type: "block", tag: "block"}` outbound, т.к. `route.final` требует тег, не
`action`). UI — `PortSelect<String>` сверху диалога, до списка правил.

### 2.2 Автокомплит geosite/geoip в поле значения правила — готово

Плавающий попап под полем (референс — shadcn Combobox), по образцу
`PortSelect`, но без анимации открытия: `CompositedTransformTarget`/
`Follower` + `OverlayEntry`, создаётся в `_RoutingRulesDialogState`
(`routing_rules_dialog.dart`). Раскрывается **только когда что-то введено и
что-то нашлось** (не на фокус — категорий geosite слишком много), лимит 5.
Имена категорий — новый `lib/engines/geo_category_index.dart`
(`geositeCategoryNames()`/`geoipCategoryNames()`, мемоизировано через
`Future<List<String>>?`, парсит `geosite.dat`/`geoip.dat` один раз за
запуск). Прогрев кэша — `connection_screen.dart`, `_ensureGeoAssets()`,
`unawaited` после `pregenerateGeoRuleSets`, не блокирует остальной
`_runStartupSequence`.

После первого прогона пользователь нашёл и попросил поправить два бага/пожелания:
- Попап автокомплита растягивался на весь экран вправо/вниз — Overlay даёт
  корню entry тугие constraints во весь экран, без `Stack`+`Positioned.fill`
  (тот же приём, что уже был в `PortSelect._open`) их некому ослабить для
  не-Positioned ребёнка. Пофикшено в `_buildSuggestionsPopover`.
- Секция настроек "Роутинг" (пресеты) отделена от "Базы роутинга"
  (geoip/geosite URL + обновление) — раньше жили в одном табе
  `_SettingsSection.routing`, теперь `_SettingsSection.routing` (пресеты,
  `S.sectionRoutingPresets`) и `_SettingsSection.routingDatabases` (базы,
  прежний `S.sectionRouting`) отдельно.

**Не проверено руками** — оба пункта (2.1/2.2) проходят `flutter analyze`/
`flutter test`, но в приложении не гонялись (см. CLAUDE.md — сам не тестирую).

**Следующий шаг:** дать пользователю погонять руками (Proxy/TUN + оба
движка — Windows и macOS), закоммитить, доисправить по фидбеку.

## 3. Импорт/экспорт пресетов по ссылке — реализовано, НЕ закоммичено

Добавлено пользователем по ходу работы над треком 2. Разовый импорт (не
живая подписка с автообновлением, в отличие от `ServerSubscription`) +
экспорт в том же формате, чтобы шарить/публиковать пресеты в репозитории.

- `RoutingPresetSource.importedUrl` + `RoutingPreset.sourceUrl`
  (`routing_preset.dart`) — для отображения происхождения, ссылка после
  импорта нигде не используется как источник обновлений.
- `lib/features/servers/routing_preset_exchange.dart` — новый файл:
  `exportRoutingPresetJson` (портируемый формат без `id`/`source`/
  `subscriptionId`/`sourceUrl`), `RoutingPresetBlueprint` +
  `parseRoutingPresetBlueprints` (принимает голый объект пресета,
  `{"presets": [...]}` или голый массив), `fetchRoutingPresetBlueprints`
  (http.get + парсинг). Модельные тесты —
  `test/features/servers/routing_preset_exchange_test.dart`.
- Импорт — `lib/features/servers/import_routing_preset_dialog.dart`, диалог
  по образцу `import_subscription_sheet.dart`, кнопка рядом с "Создать
  пресет" в `_RoutingPresetsSection` (`settings_page.dart`); каждый
  blueprint → `RoutingPreset(id: _uuid.v4(), ..., source: importedUrl,
  sourceUrl: url)` → `addRoutingPreset`.
- Экспорт — иконка-кнопка (copy) в строке пресета рядом с
  pencil/trash (не контекстное меню — в списке пресетов его не было и
  раньше, лишняя сущность ради одного пункта), сериализация +
  `Clipboard.setData` + тост.

**Не проверено руками.** `flutter analyze`/`flutter test` чисты (132 теста).

**Следующий шаг:** дать пользователю погонять импорт/экспорт руками вместе
с 2.1/2.2, затем коммитить все три трека (по одному коммиту на трек).
