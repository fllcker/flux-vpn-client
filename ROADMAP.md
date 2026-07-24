# ROADMAP.md — ближайшее развитие

Рабочий бэклог поверх PLAN.md: что доделываем прямо сейчас, в каком порядке
и какими шагами. PLAN.md — архитектура и продуктовое видение, этот файл —
текущий срез задач, правится по ходу работы (вычёркиваем сделанное,
дописываем новое).

Порядок реализации:

0. ~~Мерж состояния при рефреше подписки~~ — сделано
   (`merge_subscription_tree.dart`, см. ниже)
1. ~~Hysteria2~~ — сделано
2. ~~Скрытие серверов~~ — сделано
3. ~~Роутинг (per-server + bulk на подписку)~~ — сделано
4. ~~Пинг~~ — сделано
5. ~~Авто-режим~~ — сделано
6. ~~Drag-and-drop сортировка~~ — сделано
7. ~~Трей + автозапуск~~ — сделано
8. ~~Фон — шейдерные эффекты (Color Bends → Galaxy)~~ — сделано

Явно не делаем сейчас: второе ядро (sing-box), CI, другие платформы
(Android/iOS/macOS/Linux).

---

## Исправлено: фон под диалогами полностью затемнялся

Причина была не в `barrierColor` (его снижение до `0x14000000` было
правильным, но незаметным) — `ShadDialogRoute` создаётся с `opaque: true`
по умолчанию (`showShadDialog`'s `opaque` параметр), а Flutter для
`opaque`-маршрутов после завершения перехода перестаёт строить/красить
контент под ним вообще (не только барьер, а весь предыдущий route) — из-за
этого фон приложения не рендерился, а не потому что барьер был тёмным.
Фикс: `opaque: false` во всех вызовах `showShadDialog` (`settings_dialog.dart`,
`import_subscription_sheet.dart`, `connect_panel.dart`'s TUN-elevation
диалог). Проверено скриншотами — фон (шейдер/список серверов) корректно
просвечивает под диалогом.

## Исправлено: ширина верхнего/нижнего блока в правой панели

`IntrinsicWidth` для Row из `AnimatedContainer` (сегменты Off/Proxy/TUN)
оказался недостаточно точным — расчётная intrinsic-ширина была на
несколько пикселей меньше фактически нужной, что при определённых длинах
имени сервера приводило к `RenderFlex` overflow на самом селекторе (не на
карточке). Фикс: отказались от `IntrinsicWidth`, вместо этого
`ConnectPanel` (теперь `ConsumerStatefulWidget`) измеряет реальную
отрисованную ширину `OffProxyTunSelector` через `GlobalKey` +
`addPostFrameCallback` и задаёт эту же ширину карточке сервера явно
(`SizedBox(width: _selectorWidth)`) — точное совпадение вместо
приближённого intrinsic-расчёта. Проверено на коротком ("Germany 1") и
длинном ("Promo Promo 1") имени — оба случая совпадают по ширине без
переполнения.

---

## Аудит текущего состояния (на момент составления плана)

Заявлено в PLAN.md, но не реализовано:

- **Пинг серверов** — `EngineStats.latency` (`core_engine.dart`) никогда не
  заполняется, `PingMode` в настройках ни на что не влияет.
- **Авто-выбор по задержке (`urlTest`)** — `GroupStrategy.urlTest` и
  `AutoVariantSelection` существуют как данные, но `xray_config_mapper.dart`
  их не читает — выбор всегда ручной/первый.
- **Трафик в реальном времени** — `EngineStats.uploadBytes/downloadBytes`
  всегда 0 (`xray_engine_windows.dart`, `getStats()`), Stats API xray-core не
  подключён.
- **Drag-and-drop сортировка** — нет вообще (`Draggable`/`ReorderableListView`
  не встречаются).
- **"Показать скрытые" / скрытие сервера** — `hidden` есть в модели
  (`proxy_node.dart`), но нигде не читается и не выставляется из UI.
- **Трей/автозапуск** — не реализовано, пакета `tray_manager` нет в
  `pubspec.yaml`.
- **Импорт Clash YAML / sing-box JSON** — нет, понимаем только `vless://`,
  base64-подписки и xray-json.
- **Второе ядро** — только `XrayEngineWindows`, других реализаций
  `CoreEngine` нет.
- **`RoutingRule`** — пустой `sealed class` без единого подтипа,
  `CoreConfig.routingRules` нигде не заполняется и не используется (в новом
  дизайне ниже правила переезжают на уровень `ServerLeaf`, см. трек 3).
- **CI** — нет `.github/workflows`.
- **Другие платформы** — только `windows/`, остальных папок нет.

---

## 0. Мерж состояния при рефреше подписки — сделано

`lib/features/servers/merge_subscription_tree.dart`:
`ProxyNode mergeSubscriptionTree(ProxyNode oldRoot, ProxyNode newRoot)` —
рекурсивно обходит новое дерево, для каждого `ServerLeaf` ищет соответствие
в старом дереве по адресу первого варианта (та же логика идентичности, что
`import_to_proxy_nodes.dart` использует при группировке вариантов — id
листьев/вариантов пересоздаются заново при каждом импорте, стабилен только
адрес хоста). При совпадении сохраняются `hidden` и `selection`, а сам лист
и совпавшие по (адрес, подпись) варианты **сохраняют старые id** (контент
конфига при этом всё равно берётся свежий — ротация uuid/пароля долетает).
`selection` откатывается на авто/первый, если выбранный вариант не нашёл
пары среди новых. `subscription_import.dart` → `refreshSubscription()`
использует эту функцию вместо `root: fetched.root`. Тесты —
`test/features/servers/merge_subscription_tree_test.dart`.

Порядок (drag-and-drop, трек 6) пока не переносится — реордера ещё нет
нигде в UI, добавим вместе с треком 6, когда появится что сохранять.
`routingRules` (трек 3) тоже пока не поле модели — добавится в мерж вместе
с треком 3.

---

## 1. Hysteria2 — сделано

`Hysteria2Config` в `server_config.dart` (Magic JSON называет протокол
`hysteria2`, xray-core — `hysteria` с `version: 2` в двух местах, обфускация
Salamander опциональна — `obfsPassword == null` значит без неё).
`hysteria2_link_parser.dart` разбирает `hysteria2://auth@host:port/?...`
(алиас `hy2://`). Ветки добавлены во всех точках диспетчеризации по
протоколу: `xray_subscription_parser.dart` (xray-json подписка),
`base64_subscription_parser.dart` (построчная подписка), `subscription_import.dart`
`importLink` (одиночная ссылка) и `clipboard_import_hotkey.dart` (Ctrl+V).
`xray_config_mapper.dart`/`xray_engine_windows.dart`/`import_to_proxy_nodes.dart`
обобщены под `ServerConfig` вместо жёсткого `VlessConfig`. Тесты —
`hysteria2_link_parser_test.dart`, плюс hysteria-сервер добавлен в
`xray_subscription_parser_test.dart`.

---

## 2. Скрытие серверов — сделано

`ShadContextMenuRegion`/`ShadContextMenuItem` (в shadcn_ui готовые) на
`server_row.dart` — правый клик даёт пункт "Скрыть", виден только если
`ProxyTreeList.onHideLeaf` передан (стандалон-деревья строятся без этого
колбэка, так что там пункта нет). `proxy_node.dart` → `setNodeHidden`
(рекурсивный, аналогично `replaceLeafSelection`), `core_config_provider.dart`
→ `setHidden(nodeId, hidden)` — трогает только `subscriptions[].root`.
`filter_hidden_nodes.dart` → `filterHidden`/`filterHiddenList` — пустая
группа после фильтрации тоже пропадает. `server_list_panel.dart` фильтрует
список перед рендером дерева подписки. `subscription_info_panel.dart` —
секция "Скрытые серверы" с кнопкой "Вернуть". Тесты —
`filter_hidden_nodes_test.dart`, `core_abstraction/proxy_node_test.dart`.

---

## 3. Роутинг — per-server, с bulk-применением на подписку

Правила роутинга живут не в `CoreConfig` (глобально) и не в `Subscription`,
а **на `ServerLeaf`** — в xray-json подписке роутинг обычно приходит
отдельным блоком `"routing"` внутри JSON-объекта каждого сервера, то есть
это данные конкретного сервера, а не подписки/приложения целиком. Это же
упрощает экспорт: при подключении к серверу его `routingRules` просто идут
в `routing` секцию конфига этого подключения — не нужно ничего мержить с
глобальным уровнем.

**Поддерживаем сразу domain/IP и geosite/geoip-категории** (не только
голые домены/CIDR) — многие реальные конфиги активно используют
`geosite:category-ads`, `geoip:cn` и т.п., бандл `geoip.dat`/`geosite.dat`
уже есть в `assets/xray`. Моделируем без отдельных типов правил под
geosite/geoip — xray сам допускает смешивать обычные значения и
`geosite:`/`geoip:`-префиксы в одном списке (`domain`/`ip` массивы), так что
достаточно хранить значения как есть и копировать xray-шный синтаксис
один в один:

```dart
class DomainRule extends RoutingRule {
  final List<String> values;   // "example.com" | "domain:sub.example.com" |
                                // "regexp:..." | "geosite:category-ads"
  final String outboundTag;    // "direct" | "block" | "proxy"
}

class IpRule extends RoutingRule {
  final List<String> values;   // "1.2.3.0/24" | "geoip:cn"
  final String outboundTag;
}
```

### Хранение и импорт

1. Спроектировать `RoutingRule` (`sealed class`, сейчас пустой в
   `core_config.dart` → переехать в `proxy_node.dart` рядом с
   `ServerLeaf`, раз теперь это его поле) с подтипами `DomainRule`/`IpRule`
   как выше.
2. `ServerLeaf` — новое поле `List<RoutingRule> routingRules` (default
   `[]` = нет собственных правил, весь трафик через прокси, как сейчас).
3. `xray_subscription_parser.dart` — каждый JSON-объект в подписке (один на
   сервер) может иметь свой `"routing"."rules"` — парсим `domain`/`ip`
   массивы как есть (без интерпретации `geosite:`/`geoip:`-префиксов,
   просто сохраняем строку) и кладём на соответствующий
   `ImportedServer`/`ConnectionVariant`; при слиянии вариантов в один
   `ServerLeaf` (`import_to_proxy_nodes.dart`) берём правила первого
   варианта (в норме одинаковые у всех вариантов одного сервера).
4. Убрать `CoreConfig.routingRules` как отдельное глобальное поле (сейчас
   пустой неиспользуемый стаб) — заменяется полем на `ServerLeaf`. Заодно
   снимается запрет-исключение в `CoreConfig.fromJson` (сейчас кидает
   `FormatException`, если `routingRules` не пустой).
5. `xray_config_mapper.dart` — `buildXrayConfig`/`buildXrayTunConfig`
   принимают `leaf.routingRules` и добавляют секцию `"routing"`, если список
   не пуст — `DomainRule`/`IpRule` мапятся напрямую в xray-шные
   `{"type": "field", "domain": [...], "outboundTag": ...}` /
   `{"type": "field", "ip": [...], "outboundTag": ...}`.

### UI

1. Right-click по серверу (то же меню, что и "Скрыть") → пункт "Роутинг" →
   диалог со списком правил конкретного `ServerLeaf` + форма добавления
   (домен/IP/geosite-geoip-значение → direct/block/proxy) + удаление
   существующих.
2. На странице подписки (`subscription_info_panel.dart`) — секция
   "Роутинг", доступная в двух случаях:
   - все серверы подписки имеют **идентичный** набор правил → показываем
     этот общий набор, редактирование применяется сразу ко всем листьям
     подписки;
   - серверы отличаются → показываем предупреждение "правила различаются
     по серверам" с кнопкой **"Задать одинаковые правила для всех"** — она
     открывает тот же редактор правил и при сохранении перезаписывает
     `routingRules` у каждого `ServerLeaf` подписки одним и тем же списком.
3. `core_config_provider.dart` — `setRoutingRules(leafId, rules)` (один
   сервер) и `setRoutingRulesForSubscription(subscriptionId, rules)` (bulk,
   просто вызывает первый метод для каждого листа).

---

## 4. Пинг — сделано

`lib/features/ping/ping_service.dart` — `PingService.ping()` диспетчер по
`PingMode`: `tcp` (`Socket.connect`), `icmp` (`Process.run('ping', ...)` +
парсинг вывода), `viaProxy`. `viaProxy` реализован **не через встроенный
Observatory**, как задумывалось ниже, а через временный xray-процесс с
одним outbound'ом (`buildXrayConfig` на свободных портах) и таймингом
HTTP-запроса на `pingTestUrl` через его локальный HTTP-инбаунд — тот же
итоговый результат, без gRPC-клиента к Stats API, которого в проекте нет
(см. "Открытые вопросы" в PLAN.md). Кэш — `lib/features/ping/ping_cache.dart`
(`%AppData%\flux\ping_cache.json`, `PingCacheEntry{latencyMs, measuredAt}`,
`pingCacheProvider`) + `pingingLeafIdsProvider` для UI-состояния "сейчас
измеряется". Общая логика пинга одного/всех серверов —
`lib/features/ping/ping_all.dart` (`pingLeaf`/`pingAllLeaves`), переиспользуется
кнопкой на `server_row.dart`, кнопкой "Пинг всех" в `server_list_panel.dart` и
автопингом при старте (`connection_screen.dart`, настройка
`pingAllOnStartup` в `settings_dialog.dart`). Тесты —
`ping_service_test.dart` (TCP), `ping_cache_test.dart` (JSON round-trip).

Основа для авто-режима (трек 5) — делаем раньше него. Уже есть настройки
(`app_settings.dart`): `PingMode` (`viaProxy` / `tcp` / `icmp`) и
`pingTestUrl` (дефолт `https://www.gstatic.com/generate_204`) — сейчас ни на
что не влияют, подключаем реальную логику.

1. Новый файл `lib/features/ping/ping_service.dart` с диспетчером по
   `PingMode`:
   - **`tcp`** — просто `Socket.connect(address, port, timeout: ...)` с
     замером времени, без запуска xray. Не требует ядра — быстрее всего
     реализовать.
   - **`icmp`** — на Windows нет прямого raw-socket API без прав
     администратора; проще всего через `Process.run('ping', ['-n', '1', host])`
     и парсинг задержки из вывода (как делает `windows_elevation.dart`/
     `child_process_job.dart` с другими внешними процессами — паттерн в
     кодовой базе уже есть).
   - **`viaProxy`** — **отдельный фоновый xray-процесс с Observatory**,
     не связанный с активным подключением (подтверждено) — так пинг не
     мешает работающему TUN/Proxy-соединению и может мерить абсолютно все
     серверы разом, а не только тот, к которому сейчас подключены. У
     xray-core есть встроенный `observatory`/`burstObservatory` в
     конфиге — сам мерит latency outbound'ов по URL, ручную логику через
     временные SOCKS-порты писать не нужно. Процесс поднимается по
     требованию (по кнопке "Пинг"/"Пинг всех"), не живёт постоянно.
2. `ping_service.dart` — не часть `CoreEngine` (пинг должен уметь мерить
   **все** серверы, включая неактивные, а `CoreEngine` — это один активный
   процесс подключения); отдельный сервис, вызываемый напрямую из UI/
   провайдера.
3. **Результаты пинга сохраняются на диск** — отдельный лёгкий файл-кэш
   `%AppData%\flux\ping_cache.json` (по аналогии с
   `app_settings_storage.dart`), ключ — id листа/варианта, значение —
   `{latencyMs, measuredAt}`. Не часть Magic JSON-профиля (`profile.json`)
   осознанно: это часто меняющаяся телеметрия, не история/схема профиля,
   незачем гонять её через `schemaVersion`-миграции.
4. UI: кнопка "Пинг" на `server_row.dart` (одиночный) и кнопка "Пинг всех"
   в `server_list_panel.dart` (массовый, см. PLAN.md "Базовые функции").
   Результат — задержка в мс на строке сервера (из кэша, если есть, иначе
   пусто до первого замера), с цветовой индикацией.
5. Настройки уже есть (`settings_dialog.dart`) — просто прокинуть
   `appSettingsProvider` в `ping_service.dart` при вызове.
6. Новая настройка **"Пинговать все серверы при открытии"** — `ShadSwitch`
   в секции "Пинг" (`settings_dialog.dart`), поле `pingAllOnStartup: bool`
   в `app_settings.dart` (default `false` — не гонять сеть на каждый старт
   без явного согласия, как и `autoStartOnBoot` в треке 7). При `true` —
   `connection_screen.dart` `initState`/`_autoRefreshSubscriptions` (уже
   есть похожий паттерн там же) дополнительно вызывает "пинг всех" после
   загрузки дерева серверов.

---

## 5. Авто-режим как узел Magic JSON — сделано

`proxy_node.dart` — `AutoSelectMarker extends ProxyNode` (id + name,
дефолт "Авто"), диспетчер `ProxyNode.fromJson` понимает `type: "auto"`.
`insert_auto_select_markers.dart` — `insertAutoSelectMarkers(ProxyNode)`
рекурсивно вставляет свежий маркер первым элементом в каждую `ServerGroup`
(вложенные тоже); вызывается один раз в `subscription_import.dart` при
построении дерева подписки (после `groupLeavesByName`), в т.ч. на
рефреше — маркер не переносится через `merge_subscription_tree.dart`
(пересоздаётся каждый раз, состояния не несёт). `pick_best_by_latency.dart`
— чистая функция `pickBestByLatency(leaves, pingCache) -> id?`, игнорирует
как отсутствующие, так и устаревшие (>5 минут) записи кэша пинга. Клик по
строке "Авто" в `proxy_tree_list.dart` (иконка ⚡, компонент `_AutoRow`)
собирает `flattenLeaves` всех серверов группы (рекурсивно, вложенные группы
тоже, свои Auto-маркеры пропускаются) и в `server_list_panel.dart` выбирает
лучший по кэшу — либо, если кэша нет, первый по списку + фоновый
`pingAllLeaves` на будущее; сам выбор "проваливается" в обычный
`onSelectLeaf`, так что дальше в UI подсвечивается как обычно выбранный
сервер (никакого отдельного понятия "активен через Авто" не заводили,
см. ниже про пределы v1). `core_config_provider.dart` →
`markGroupAutoSelected(groupId)` фиксирует `GroupStrategy.urlTest` на
группе (данные, никуда пока не читаются, задел под трек live failover).
Поскольку `ProxyNode` — sealed class, добавление `AutoSelectMarker`
потребовало явного case во всех исчерпывающих switch по дереву:
`replaceLeafSelection`/`setNodeHidden`/`setLeafRoutingRules` (проброс без
изменений), `filter_hidden_nodes.dart` (группа, где после фильтрации
скрытых остался только маркер, тоже пустая — дропается),
`flatten_leaves.dart`/`core_config_provider._flattenLeaves` (пропускается,
не реальный сервер), `xray_engine_windows._firstLeaf` (пропускается при
поиске первого подключаемого листа). Тесты —
`insert_auto_select_markers_test.dart`, `pick_best_by_latency_test.dart`,
плюс кейсы на проброс/JSON в `proxy_node_test.dart`,
`filter_hidden_nodes_test.dart`.

Live failover (авто-переподключение при обрыве текущего сервера) — не
сделан, `pickBestByLatency` спроектирован под это, но вызывающая сторона
(таймер/детект обрыва) не реализована, см. "V1" ниже.

Отдельный узел (не флаг на группе) — даёт больше свободы в UI: можно
кликнуть, увидеть, какой сервер сейчас активен по факту.

**V1 — разовый выбор**, не live failover: при выборе/подключении к "Авто"
однократно берём сервер с наименьшей latency из кэша пинга (трек 4), если
кэш пустой/устаревший — сначала гоняем пинг по группе, потом выбираем.
Если сервер отвалится **во время** активного соединения — переподключаться
вручную, автоматического failover нет.

Специально архитектурно закладываем **возможность добавить live failover
позже** без переписывания: сам выбор "лучшего по пингу" реализовать как
чистую функцию `pickBestByLatency(List<ServerLeaf/ConnectionVariant>, pingCache) -> id`,
не завязанную на UI-событие "нажал/подключился" — тогда в будущем её же
можно будет вызывать по таймеру/при детекте обрыва, не трогая саму логику
выбора.

1. `proxy_node.dart` — новый вариант `ProxyNode`: `AutoSelectMarker` (id,
   лежит первым элементом в `ServerGroup.children`).
2. `pickBestByLatency(...)` (см. выше) — используется при выборе "Авто" в
   UI; при отсутствии свежих данных пинга — fallback на первый по списку
   (и триггерит фоновый пинг группы, чтобы данные появились к следующему
   разу).
3. При конвертации сторонних конфигов (`xray_subscription_parser.dart`,
   `base64_subscription_parser.dart`, будущий Clash/sing-box импорт) — после
   `group_leaves_by_name.dart` автоматически вставлять "Авто" первым
   элементом в каждую получившуюся `ServerGroup`.
4. UI: `server_row.dart`/`proxy_tree_list.dart` — рендер строки "Авто"
   (например иконка ⚡ вместо флага), выбор её сохраняет
   `GroupStrategy.urlTest`/аналог на группе.

---

## 6. Drag-and-drop сортировка серверов/групп — сделано

`proxy_node.dart` — `moveNodeInTree(root, nodeId, newParentGroupId, newIndex)`:
извлекает узел из дерева (`_extractNode`/`_extractFromGroup`), проверяет,
что группа-цель существует в этом же дереве (`_containsGroup`) — если нет,
откатывается к исходному `root` без изменений, а не молча теряет узел
(важно: перетаскивание между разными подписками физически возможно на
уровне Flutter-жестов, `DragTarget` не знает о границах поддеревьев), затем
вставляет (`_insertNode`/`_insertAt`, с защитой — вставка перед
`AutoSelectMarker`-ом на индексе 0 сдвигается на 1, он всегда первый).
`core_config_provider.dart` → `moveNode(nodeId, newParentGroupId, newIndex)`
— спецзначение `newParentGroupId == standaloneParentId` маршрутизирует в
отдельную `_reorderStandalone` (плоский список без своей группы), иначе
прогоняет `moveNodeInTree` по каждой подписке (self-contained на
подписку — операция либо целиком применяется в дереве, где нашёлся и узел,
и цель, либо нигде). UI — `proxy_tree_list.dart`: каждая строка сервера/
группы обёрнута в `Draggable<String>`+`DragTarget<String>`
(`_dragWrap`) — дроп на сервер переставляет перед ним на этом же уровне,
дроп на группу перемещает внутрь неё (в конец), плюс `_TrailingDropZone` в
конце каждого уровня для вставки в конец списка. `AutoSelectMarker` не
оборачивается в `_dragWrap` вообще — не перетаскиваемый и не принимает
дропы. Проверено вручную в запущенном приложении (`flutter run -d
windows`) — оба сценария (реордер внутри группы, перенос между группами)
отработали и сохранились в профиль. Тесты — кейсы на `moveNodeInTree` в
`proxy_node_test.dart` (реордер, перенос в другую группу, no-op на
отсутствующий узел/цель без потери узла, защита `AutoSelectMarker`).

**Пост-фактум фикс: кнопка "Сбросить сортировку" и `mergeSubscriptionTree`
переработаны.** Первая версия кнопки пыталась пересобрать группировку
локально (`groupLeavesByName` по текущим листьям, без похода в сеть) — не
работает принципиально: префикс группы ("Basic - " в "Basic - Germany 1")
вырезается из имени листа уже при первом импорте и нигде отдельно не
хранится, так что локально его неоткуда взять — попытка перегруппировать
по уже урезанным именам ломает структуру. Заодно вскрылось, что обычный
рефреш подписки тоже отбрасывал ручную сортировку (трек 0 никогда не
задумывал сохранять порядок, только `hidden`/`selection`) — пользователь
явно попросил обратное. Итог — `merge_subscription_tree.dart` теперь
предоставляет два разных обхода:

- `mergeSubscriptionTree(oldRoot, newRoot)` (дефолт, обычный рефреш и
  автообновление при старте) — обходит **старое** дерево как основу
  (`_preserveStructure`), подтягивает свежее содержимое совпавших по
  адресу листьев, дропает пропавшие, дописывает (`_appendNewLeaves`)
  реально новые серверы — в одноимённую существующую группу по префиксу
  имени, если нашлась, иначе через `groupLeavesByName` в конец. Порядок и
  ручная группировка (в т.ч. drag-and-drop) переживают рефреш.
- `resetSubscriptionOrder(oldRoot, newRoot)` (только кнопка "Сбросить
  сортировку", требует сеть) — обходит **новое** дерево (старая логика
  до фикса), сохраняя только `hidden`/`selection` по адресу, порядок и
  группировка берутся полностью свежими из источника.

`refreshSubscription(..., resetOrder: false)` — новый параметр,
переключает стратегию; `subscription_info_panel.dart` — кнопка вызывает
`_refresh(subscription, resetOrder: true)` вместо локального пересчёта.
Проверено вручную: обычный рефреш сохраняет перетащенный вручную сервер в
чужой группе, "Сбросить сортировку" корректно возвращает его в исходную
группу с сервера. Тесты — `merge_subscription_tree_test.dart` дополнен
кейсами на сохранение структуры при рефреше, добавление нового сервера в
существующую группу и на `resetSubscriptionOrder`.

1. `proxy_tree_list.dart` — заменить статичный список на
   `ReorderableListView`/кастомный `Draggable`+`DragTarget` по строкам
   дерева. Учесть вложенность (перетаскивание внутри одной группы — простой
   реордер списка; между разными группами — перенос элемента из одного
   `children` в другой).
2. Перетаскивание **только внутри одной подписки или внутри standalone-
   списка** — перенос узла из подписки в standalone (или в другую подписку)
   не поддерживаем: subscription-дерево на следующем рефреше всё равно
   пересобирается с нуля (мерж из трека 0 сохраняет только позицию/
   hidden/routingRules существующих узлов, не переносы между разными
   родительскими деревьями).
3. `core_config_provider.dart` — метод `moveNode(nodeId, newParentId, newIndex)`
   — рекурсивно находит и удаляет узел из старого `children`, вставляет в
   новый по индексу. Порядок — часть Magic JSON, сохраняется как есть (уже
   заложено в модели — `children` это просто `List`).
4. `AutoSelectMarker` (трек 5) — не перетаскиваемый, всегда остаётся первым
   элементом группы.

---

## 7. Трей-иконка и автозапуск — сделано

`lib/app/tray.dart` — `FluxTray` (`with TrayListener`), держит явный
`ProviderContainer` (не `WidgetRef` — обработчики кликов по трею живут вне
дерева виджетов), иконка — `assets/tray_icon.ico` (копия
`windows/runner/resources/app_icon.ico`, добавлена в `pubspec.yaml` assets,
т.к. `trayManager.setIcon` резолвит путь только через Flutter-ассеты).
Меню — Открыть / Подключить-Отключить (лейбл и действие зависят от
`connectionControllerProvider`, подписка через `container.listen`) /
Выход. Левый и правый клик оба открывают меню (`popUpContextMenu()`) —
так делает сам tray_manager в примере для Windows.

`main.dart` — вместо голого `ProviderScope` теперь явный
`ProviderContainer` + `UncontrolledProviderScope`, чтобы `tray.dart` мог
читать/писать через тот же контейнер. `windowManager.setPreventClose(true)`
сразу после первого `runApp`; `_FluxAppState` (`with WindowListener`) →
`onWindowClose()` вызывает `windowManager.hide()` — обработчик крестика в
`app_title_bar.dart` не тронут, он как и раньше зовёт `windowManager.close()`,
но с `preventClose` это теперь просто триггерит `onWindowClose` вместо
настоящего закрытия. Реальный выход — только пункт "Выход" в трее
(`tray.dart`), который сначала снимает `preventClose`.

`lib/app/windows_autostart.dart` — `setAutoStartOnBoot(bool)`, по аналогии с
`deep_link.dart`: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`,
значение `"<exePath>" --minimized`. `main()` проверяет `--minimized` в
`args` и пропускает `show()`/`focus()` при старте (окно остаётся скрытым,
доступно через трей). `app_settings.dart` → `autoStartOnBoot: bool`
(default `false`), переключатель в `settings_dialog.dart` пишет в реестр
синхронно с сохранением настройки.

Проверено вручную (`flutter run -d windows`): закрытие окна сворачивает в
трей, процесс остаётся жив со скрытым окном (не завершается); отладочная
консоль без исключений при настройке иконки/меню. Всплывающее меню трея
(Windows notification overflow) не удалось надёжно заскриншотить через
синтетический клик для визуальной проверки пунктов — сама механика
(`tray_manager` API, подписка на `connectionControllerProvider`) проверена
код-ревью, а не скриншотом.

1. Добавить `tray_manager` в `pubspec.yaml`.
2. `main.dart`/новый `lib/app/tray.dart` — иконка в трее, меню (Открыть /
   Подключить-Отключить / Выход). Обработчик закрытия окна — вместо
   `windowManager.close()` вызывает `windowManager.hide()`; реальный
   `windowManager.close()`/`exit()` — только из пункта "Выход" в трее.
3. Автозапуск при старте Windows — **настройка в `settings_dialog.dart`,
   по умолчанию выключена**. Реализация — по аналогии с
   `deep_link.dart` (уже пишет в реестр через `win32_registry`):
   ключ `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, значение —
   путь к `.exe` (+ флаг типа `--minimized`, чтобы автозапуск открывал
   приложение сразу свёрнутым в трей, не мозоля окном при старте системы).
4. `app_settings.dart` — новое поле `autoStartOnBoot: bool` (default
   `false`), запись/удаление реестрового ключа синхронно с изменением
   настройки.

---

## 8. Фон — шейдерные эффекты (Color Bends → Galaxy) — сделано

Оба взяты с [reactbits.dev](https://reactbits.dev) (react-bits, MIT,
[github.com/DavidHDev/react-bits](https://github.com/DavidHDev/react-bits),
папка `Backgrounds`). Оба реализованы там как WebGL fragment-шейдеры
(Color Bends — Three.js, Galaxy — OGL) — это ровно то, что умеет нативно
Flutter через `dart:ui` fragment shaders (`.frag`, компилируется `impellerc`,
рисуется через `FragmentShader` + `CustomPainter`), так что порт — это
построчный перенос GLSL-математики, а не переизобретение рендера.

**Simple Gradient и Color Bends — сделано и визуально финально**, менять
их вид не нужно. Оба полноценно подключены (не прототип): `shaders/
color_bends.frag`/`shaders/simple_gradient.frag` +
`lib/widgets/globe/shader_background.dart` (общая обвязка —
`FragmentProgram.fromAsset` + `CustomPainter`, `uSize`/`uTime` уходят в
шейдер как uniform'ы, `uTime` двигает `Ticker`) — `HomeBackground`
(`app_settings.dart`) содержит варианты `simpleGradient`/`colorBends`
наравне с `none`/`globe`, оба выбираются в `ShadSelect` настроек
(`settings_dialog.dart`) и рендерятся через `switch` по `HomeBackground` в
`connection_screen.dart`. Цвета/параметры (`ITERATIONS`, `FREQUENCY`,
`WARP_STRENGTH`, `BAND_WIDTH`, `INTENSITY` и т.п.) всё ещё зашиты как
`const` прямо в `.frag`, не вынесены в настраиваемые uniform'ы — это
осталось из черновика, но трогать не нужно **если только не понадобится
менять их извне Dart-кода** (например, если Galaxy или будущая настройка
интенсивности потребует передавать параметры динамически — тогда выносить
в uniform'ы вместе с этой задачей, не заранее).

**Galaxy — сделано.** `shaders/galaxy.frag` — построчный порт fragment-
шейдера react-bits `Galaxy.jsx` (получен через WebFetch с GitHub,
исходник взят как есть, не по памяти): hash-based процедурная генерация
звёзд (`Hash21`/`StarLayer`), 4 слоя глубины для параллакса (`NUM_LAYER`),
HSV-сдвиг цвета (`hsv2rgb`, `HUE_SHIFT`), мерцание через треугольную волну
(`trisn`/`TWINKLE_INTENSITY`). Упрощено тем же способом, что и Color
Bends/Simple Gradient — настраиваемые uniform'ы оригинала
(`density`/`hueShift`/`glowIntensity`/...) зафиксированы константами со
значениями по умолчанию из react-bits; убрана mouse-интерактивность
(repulsion, офсет фокуса под курсор — у `ShaderBackground` нет пайплайна
для позиции мыши) и ручное вращение (`uRotation` оригинала) — оставлена
только авто-ротация; всегда непрозрачный (`transparent: true` оригинала
не имеет смысла для полноэкранного базового фона). `SPEED`/
`ROTATION_SPEED`/`STAR_SPEED` дополнительно снижены против дефолтов
react-bits (в ~3 раза) — на полноэкранном фоне оригинальная скорость
ощущалась слишком суетливой (мерцание/параллакс-скролл звёзд бросались в
глаза). Подключён тем же способом, что и два предыдущих: `pubspec.yaml`
→ `shaders:`, `HomeBackground.galaxy`, опция в `ShadSelect`
(`settings_dialog.dart`), ветка в `switch` (`connection_screen.dart`).
Проверено вручную (`flutter run -d windows`) — компилируется без ошибок
impellerc, рендерится корректно, скорость подтверждена пользователем.

Не проверено: производительность/нагрев на слабом железе — фон рисуется
каждый кадр на весь экран для всех трёх шейдеров, стоит проверить, не
роняет ли это FPS остального UI поверх (список серверов и т.п.) на
реальном ноутбуке, не только на разработческой машине.
