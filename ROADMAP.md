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
9. ~~Запоминание выбранного сервера между запусками~~ — сделано (см. ниже)
10. ~~Аудит настроек~~ — сделано (см. ниже)
11. ~~Запрет пинга во время активного TUN~~ — сделано (см. ниже)
12. ~~Документация Magic JSON конфига в `docs/`~~ — сделано (см. ниже)
13. ~~Установщик вместо portable-сборки~~ — сделано, не проверено
    компиляцией (см. ниже)
14. ~~Кастомные k:v поля информации о подписке~~ — сделано (см. ниже)
15. ~~Аудит сценариев переключения proxy/TUN/сервера при активном
    соединении~~ — сделано, гонка пофикшена, чеклист на ручную проверку
    (см. ниже)
16. Адаптивность через resize окна — первый шаг сделан (мобильная раскладка
    `ConnectionScreen`), остальные экраны и TV-раскладка не тронуты
    (см. ниже)
17. ~~CI: автосборка релиза при бампе версии~~ — сделано
    (`.github/workflows/release.yml`, см. ниже)
18. ~~Светлая тема + локализация RU/EN~~ — сделано (см. ниже)

Явно не делаем сейчас: другие платформы (Android/iOS/macOS/Linux).

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

---

## 9. Запоминание выбранного сервера между запусками — сделано

`AppSettings` (`core_abstraction/app_settings.dart`) — новое поле
`lastSelectedServerId: String?`, сериализуется в `toJson`/`fromJson` как
предпочтение этой машины (не часть Magic JSON-профиля, `CoreConfig` не
трогали). `selected_server_provider.dart` →
`SelectedServerIdController.build()` теперь читает его через
`ref.watch(appSettingsProvider)` и **проверяет существование id в текущем
дереве** (`flattenAllLeaves(ref.watch(coreConfigProvider))`) при каждой
пересборке — если сервер пропал (удалили из подписки, снесли подписку,
рефреш пересобрал дерево), `build()` возвращает `null`, и все три
потребителя (`connect_panel.dart`, `connection_screen.dart`,
`server_list_panel.dart`) проваливаются на уже существовавший фолбэк
«первый лист дерева» без изменений на их стороне. `select(id)` пишет и в
`state`, и сразу в `appSettingsStorage` через
`appSettingsProvider.notifier.update(...)`.

Не сделано (осознанно, см. открытый вопрос ниже): случай, когда выбран узел
внутри группы с `AutoSelectMarker` (трек 5) — авто-режим сейчас вообще не
заводит отдельного состояния "выбран через Авто", он один раз резолвит
лучший сервер и сохраняет обычный `selectedServerIdProvider.select(bestId)`
— то есть между запусками восстановится именно этот когда-то выбранный
конкретный сервер, а не "снова спросить Авто, какой сейчас лучший". Если
нужно, чтобы Авто оставался Авто между запусками — отдельная задача поверх
этой (потребует запоминать не id листа, а факт "эта группа была в
авто-режиме").

---

## 10. Аудит настроек — какие реально на что-то влияют — сделано

Прогнали по всем полям `AppSettings` (`core_abstraction/app_settings.dart`):

- `homeBackground`, `pingMode`, `pingTestUrl`, `pingAllOnStartup`,
  `tunCoreType`, `tunDnsServer`, `autoGroupSubscriptions`, `autoStartOnBoot`,
  `coreLogLevel` — все реально used, подключены к конкретному коду
  (`connection_screen.dart`, `ping_all.dart`/`ping_service.dart`,
  `connection_controller.dart`, `windows_autostart.dart` и т.д.).
- **`themeMode` — была заглушка**, сохранялась и отображалась в UI, но
  нигде не применялась (портировать светлую тему — отдельная немаленькая
  задача, весь `port_ui` сейчас на одной тёмной палитре `PortColors`, вне
  скопа этого трека). Портировать полностью не стали — вместо этого явно
  пометили в UI: `settings_page.dart`, секция "Персонализация" — под
  селектом темы добавлена приглушённая подпись "Пока без эффекта —
  приложение всегда в тёмной теме, светлая ещё в разработке". Сам селект
  оставлен рабочим (значение по-прежнему сохраняется в `AppSettings`) — так
  проще один раз доделать применение позже, не трогая UI повторно.

При появлении новых настроек в будущем — сразу проверять, что контрол
действительно доходит до используемого в рантайме значения, а не только до
`AppSettings`/`app_settings_storage.dart`.

---

## 11. Запрет пинга во время активного TUN + тост — сделано

`ping_all.dart` → `isTunActive(WidgetRef ref)` — читает
`connectionControllerProvider`, `true` если `ConnectionConnected(mode:
ConnectionMode.tun)`. `pingLeaf` теперь начинается с тихого no-op при
`isTunActive` (защита самого запуска — покрывает и авто-пинг при старте, и
любой будущий программный вызов, не только клики из UI); `pingAllLeaves`
защищён транзитивно, раз просто зовёт `pingLeaf` по списку.

На explicit-клике показываем тост, а не молча игнорируем — `server_list_panel.dart`:
`onPingLeaf`/новый `onPingAll` проверяют `isTunActive` до вызова
`pingLeaf`/`pingAllLeaves` и показывают `PortToaster.of(context).show(...)` с
объяснением ("измерение мешает активному TUN-соединению") через уже
существующий `PortToast`. Ограничение сделано **бланкетным** — на все
`PingMode` (`viaProxy`/`tcp`/`icmp`), не только на `viaProxy` — открытый
вопрос из плана закрыт в пользу простоты: не только `viaProxy` физически
рискует конфликтом портов, ICMP/TCP-пинг тоже создаёт впечатление, что
измерение в TUN-режиме уместно, хотя реально ничего полезного не меряет
(трафик и так идёт через TUN-адаптер, а не через тестируемый outbound).

---

## 12. Документация Magic JSON конфига в `docs/` — сделано, затем поправлено

Первая версия документа (см. историю) утверждала, что "генерировать сам
Magic JSON не нужно — Flux не умеет импортировать его напрямую по URL", и
описывала xray-json как основной формат для внешнего сервиса. **Это было
неправильно** — пользователь поправил: MJ изначально задумывался именно
для того, чтобы его собственный VPN-сервис мог генерировать конфиг
напрямую под Flux, без конвертации через xray-json туда и обратно. Плюс
исходная модель "MJ = `CoreConfig`" тоже была неверной — `CoreConfig`
(много подписок + standalone-узлы разом) это формат локального хранилища
на диске пользователя, а не то, что разумно отдавать одним HTTP-ответом;
единица передачи по одному URL должна быть мельче — либо подписка(и),
либо плоский набор нод.

**Реализовано** — Flux теперь принимает MJ напрямую по URL подписки, в
конверте вида (см. `lib/core_abstraction/mj_payload.dart`):

```json
{ "schemaVersion": 1, "type": "subscriptions", "content": [ /* Subscription[] */ ] }
{ "schemaVersion": 1, "type": "nodes", "content": [ /* ProxyNode[] */ ] }
```

- `subscription_import.dart` → `importLink` определяет этот формат по
  телу ответа (JSON-объект с `schemaVersion`/`type`/`content` на верхнем
  уровне — не пересекается с xray-json, у того `remarks`/`outbounds`) и
  парсит через `MjPayload.fromJson` — переиспользует уже существующие
  `Subscription.fromJson`/`ProxyNode.fromJson`, отдельного конвертера не
  потребовалось, раз это и есть родной формат клиента.
- Новый результат `MjImportResultOk` в `LinkImportResult` — обрабатывается
  и в диалоге добавления сервера (`import_subscription_sheet.dart`), и в
  Ctrl+V (`clipboard_import_hotkey.dart`) через общий помощник
  `apply_mj_payload.dart` → `applyMjPayload(ref, payload)`: для
  `subscriptions` — upsert по `Subscription.id` (совпал — мерж дерева тем
  же `mergeSubscriptionTree`, что и обычный рефреш подписки, не совпал —
  добавляется новая); для `nodes` — новый `CoreConfigController.
  applyMjNodes` делает то же самое по id среди `standaloneNodes`.
- `refreshSubscription` (кнопка "Обновить" на странице подписки) тоже
  понимает MJ: если URL этой подписки отдаёт `type: "subscriptions"`,
  ищет в присланном массиве элемент с тем же `id`, что и обновляемая
  подписка, и мержит его тем же путём, что и xray-json-рефреш — с точки
  зрения остального кода (`SubscriptionInfoPanel`) ничего не изменилось,
  разворачивание MJ происходит полностью внутри `subscription_import.dart`.
- **`id` — обязанность сервиса, не клиента**: сопоставление "это тот же
  объект, что и в прошлый раз" происходит по присланному `id`, значит
  сервис должен генерировать и стабильно переиспользовать одни и те же id
  между запросами к одному и тому же URL — иначе на каждом рефреше
  элемент будет выглядеть как "старый исчез, новый появился" (потеря
  `hidden`/сортировки/ручного выбора варианта).
- Тесты — `test/core_abstraction/mj_payload_test.dart` (парсинг обоих
  типов, отклонение неизвестной версии/типа, `looksLikePayload` отличает
  конверт от xray-json).

`docs/magic_json.md` переписан: §1 теперь — MJ напрямую (рекомендуемый
путь), §2 — xray-json/base64 как fallback для панелей, которые про Flux
не знают, §3 — схема MJ-типов (`Subscription`/`ProxyNode`/`ServerConfig`/
`RoutingRule`) уже без ложной привязки к `CoreConfig` как единице
передачи.

Не реализовано: `type: "nodes"` не участвует в цикле рефреша вообще (это
одноразовый импорт, как ручное добавление standalone-серверов) — если
понадобится "подписка на набор нод без подписки-обёртки", это отдельная
задача. Также синхронизировано с треком 14 — `Profile-Custom-Fields`
(fallback-заголовок) в доке по-прежнему описан отдельно от MJ-конверта, у
которого свои поля `customFields` прямо в `Subscription`.

---

## 13. Установщик вместо portable-сборки — сделано (не проверено локальной компиляцией)

Выбран **Inno Setup** из трёх рассмотренных вариантов (MSIX требует
сертификат/Store, Squirrel заточен под фоновый автоапдейтер — не то, что
просили) — простой `.exe`-установщик, повторный запуск с новой версией
поверх старой просто заменяет файлы.

`windows/installer/flux.iss`:

1. Фиксированный `AppId` (GUID `8EF5C60B-CBFC-4B32-9EF3-267C79268C4E`,
   захардкожен в скрипте, никогда не меняется между версиями) — то, что
   говорит Inno Setup "это апдейт существующей установки", а не новая копия
   рядом.
2. `DefaultDirName={localappdata}\Flux`, `PrivilegesRequired=lowest` — установка
   без прав администратора, TUN-режим и так просит elevation отдельно во
   время работы (`windows_elevation.dart`), самому инсталлятору это не
   нужно.
3. `CloseApplications=force` + `RestartApplications=no` — Inno Setup 6
   использует Windows Restart Manager, чтобы обнаружить процессы,
   держащие открытыми файлы, которые заменяются (`flux.exe`/DLL), и
   предложить их закрыть — отдельный `AppMutex` не понадобился (в
   приложении нет именованного mutex для single-instance, используется
   loopback-порт, `single_instance.dart`, — Restart Manager всё равно ловит
   сам факт блокировки файла процессом, ему конкретный механизм
   single-instance не важен).
4. `%AppData%\flux\` (настройки, профиль, кэш пинга) не упоминается в
   `[Files]`/`[UninstallDelete]` вообще — не трогается ни при апдейте, ни
   при удалении.
5. `[Icons]` — Пуск всегда, рабочий стол — опциональная задача
   (`[Tasks] desktopicon`), Inno Setup сам не дублирует ярлыки при
   повторной установке того же `AppId`.
6. `[Files]` берёт **всю** папку `build\windows\x64\runner\Release\*`
   целиком — xray-core/sing-box (`assets/xray`, `assets/sing-box`) уже
   копируются туда `windows/CMakeLists.txt`'s `install()`-правилами при
   обычной `flutter build windows`, так что упаковывать бинарники ядер
   отдельно не пришлось.

`scripts/build_installer.ps1` — обёртка: гоняет `flutter build windows
--release`, вытаскивает версию из `pubspec.yaml` (`1.0.0+1` → `1.0.0`,
Inno не понимает `+build`-суффикс), зовёт `iscc.exe /DAppVersion=... windows\installer\flux.iss`.
Результат — `build\installer\FluxSetup-<version>.exe`.

**Не проверено** — Inno Setup (`iscc.exe`) не установлен на этой машине,
компиляция `.iss`-скрипта не прогонялась локально ни разу. Синтаксис
выверен по документации Inno Setup 6, но перед первым реальным релизом
нужно: поставить Inno Setup, прогнать `scripts/build_installer.ps1`,
проверить установку/апдейт/деинсталляцию вручную (см. чеклист ниже) —
сам не устанавливал стороннее ПО на систему без явного запроса.

Проверить после установки Inno Setup: чистая установка на пустую машину,
установка новой версии поверх старой (файлы заменились, ярлыки не
задвоились, `%AppData%\flux\profile.json` пользователя не пострадал),
попытка установить новую версию поверх старой при запущенном
`flux.exe` (должен либо сам закрыть, либо явно попросить закрыть — не
падать молча), деинсталляция (приложение и ярлыки удалены,
`%AppData%\flux\` осталась).

---

## 14. Кастомные k:v поля информации о подписке — сделано

`Subscription` (`core_abstraction/subscription.dart`) — новое поле
`Map<String, String> customFields` (default `{}`), сериализуется в
`toJson`/`fromJson` как объект, часть Magic JSON.

Источник — **новый отдельный HTTP-заголовок**, не расширение
`Subscription-Userinfo`: `subscription_import.dart` → `_parseCustomFields`
читает `Profile-Custom-Fields`, значение — JSON-объект, закодированный тем
же способом, что уже используется для `Announce` (`base64:<...>`), например
`Profile-Custom-Fields: base64:eyJUYXJpZiI6IlByZW1pdW0ifQ==` (раскодируется
в `{"Тариф": "Premium"}`). Отдельный заголовок, а не расширение
`Subscription-Userinfo`, выбран потому что тот формат (`key=value;
key=value`, значения — числа) не подходит для произвольного UTF-8 текста
(кириллица, длинные строки) без экранирования — тащить это в уже занятый
числами заголовок было бы грязнее, чем завести свой. Формат зафиксирован в
`docs/magic_json.md` (трек 12) для внешнего сервиса-генератора.

`refreshSubscription` прокидывает `fetched.customFields` в пересобранную
`Subscription` при каждом рефреше — полностью заменяются свежими, не
мержатся с предыдущими (как `traffic`/`expiresAt`), это динамические данные
сервиса, а не пользовательское состояние вроде `hidden`/`selection`.
`merge_subscription_tree.dart` трогать не пришлось — он мержит только дерево
`ProxyNode`, метаданные `Subscription` (включая `customFields`) не его
área, `refreshSubscription` собирает их отдельно.

UI — `subscription_info_panel.dart`: цикл по `subscription.customFields.
entries`, каждая пара рендерится существующим `_InfoRow` (лейбл/значение),
вставлено перед секцией `annotation`. Порядок — как пришли (`Map` в Dart
сохраняет порядок вставки).

---

## 15. Аудит сценариев переключения proxy/TUN/сервера при активном соединении — сделано

Текущее поведение (`connection_controller.dart` → `connectToServer`,
`connect_panel.dart` → `_onSelectionChanged`) — единая точка входа для всех
трёх сценариев, разбора по случаям сейчас нет:

- **Proxy → TUN на лету**, **TUN → Proxy на лету**, **другой сервер при
  активном соединении** — все три вызывают один и тот же `connectToServer`,
  который безусловно: `ConnectionConnecting` → останавливает текущий движок
  (`engineManager.removeEngine`) → поднимает новый под целевой режим/сервер.
  То есть по факту всегда полный disconnect+reconnect, никогда не "патчит"
  существующее соединение на лету. Это осознанное решение из прошлого фикса
  (комментарий в коде про осиротевший `xray.exe`/wintun-адаptor при попытке
  просто подменить движок без остановки) — соответственно **не баг**, но
  стоит явно задокументировать как поведение, а не как то, что "просто
  работает само".
- **TUN конкретно** — дополнительно требует elevation
  (`isRunningElevated()` в `connect_panel.dart`); если не elevated — диалог
  с перезапуском приложения от администратора, который **сначала гасит
  текущее соединение** (`disconnect()`), потом релончит процесс. Значит
  сценарий "Proxy активен → жмём TUN, но не elevated" не просто переключает
  режим, а полностью убивает старое соединение и просит перезапуск всего
  приложения — стоит проверить, насколько это очевидно из UI в моменте
  (спиннер/тост "потребуется перезапуск", а не молчаливый обрыв).
- **Гонки при быстрых повторных кликах** — на уровне UI `busy` (`connect_
  panel.dart`, `state is ConnectionConnecting || state is ConnectionStopping`)
  блокирует переключатель во время перехода, но это был только UI-guard;
  `ConnectionController.connectToServer` сам по себе не был защищён от
  параллельного вызова, если что-то дёрнет его программно (например, трей —
  `tray.dart` — тоже умеет дёргать подключение). **Пофикшено**:
  `connection_controller.dart` — `_generation` (монотонный счётчик),
  `connectToServer`/`disconnect` бьют себе номер в начале и после каждого
  `await` сверяются, не обогнал ли их более новый вызов — если да, тихо
  выходят, не трогая `state`/`_engine` (не как раньше, когда застрявший
  старый вызов после своего `await` мог перезаписать состояние, выставленное
  уже более новым). Не меняет happy-path поведение (обычный одиночный вызов
  просто всегда "самый новый"), только защищает от гонки при перекрытии двух
  вызовов.

План: помимо фикса гонки выше — ревью + чеклист сценариев для ручной
проверки (юзер тестирует сам, см. правило в `CLAUDE.md` — не тестировать
proxy/TUN самостоятельно):

1. Off → Proxy → TUN (без перезапуска, elevated) → Off.
2. Off → TUN (не elevated) → подтверждение диалога → перезапуск → TUN
   поднимается сам после релонча.
3. Proxy активен → смена сервера (тот же режим) → должен быть чистый
   reconnect на новый сервер, без утечки старого процесса.
4. TUN активен → смена сервера → то же самое, плюс проверить, что
   wintun-адаптер/маршруты корректно пересоздаются, не задваиваются.
5. Быстрый двойной клик по переключателю во время перехода (`busy`) —
   второй клик должен быть либо заблокирован UI, либо безопасно
   проигнорирован на уровне контроллера.
6. Переключение из трея, пока в главном окне уже идёт переход
   (`ConnectionConnecting`/`ConnectionStopping`).

---

## 16. Адаптивность через resize окна — desktop/mobile/TV брейкпоинты — первый шаг сделан

Реализован первый проход (механизм + мобильная раскладка `ConnectionScreen`),
не полная адаптация всех экранов — см. остаток плана ниже.

1. `main.dart` — `minimumSize` снижен с `760×480` до `320×480`, `size`
   (стартовый `960×620`) не тронут — десктопный дефолт как был. Теперь окно
   физически можно ужать до мобильных пропорций resize'ом прямо на Windows.
2. `lib/app/layout_breakpoints.dart` — новый файл, `kMobileBreakpoint = 560.0`
   + `isMobileLayout(BuildContext)`. Порог проверяется по ширине окна
   (`LayoutBuilder`/`MediaQuery`), не по платформе — так и было задумано для
   этого шага (единственная платформа сейчас — Windows).
3. `connection_screen.dart` — `LayoutBuilder` вокруг всего экрана:
   - **Обычная раскладка** (`constraints.maxWidth >= kMobileBreakpoint`) —
     без изменений, `Row(ServerListPanel(), Expanded(mainContent))`.
   - **Мобильная раскладка** (уже `< kMobileBreakpoint`) — `mainContent`
     (фон + `ConnectPanel`/`SubscriptionInfoPanel`) на весь экран без
     сайдбара, плюс плавающая кнопка (`PortIconButton.secondary`, иконка
     "список") в левом верхнем углу, открывающая список серверов через новый
     `showPortBottomSheet`.
   - Кнопка — **слева**, не справа: справа в мобильной раскладке по плану
     должна была бы сидеть кнопка настроек без тайтлбара, но эта часть плана
     (см. п.4 ниже) сознательно не реализована в этом шаге — тайтлбар с
     кнопкой настроек всегда виден на Windows независимо от ширины, значит
     верхний правый угол уже занят им, а не свободен для второй кнопки.
4. `lib/widgets/port_ui/port_bottom_sheet.dart` — новый компонент
   `showPortBottomSheet` (по образцу `showPortDialog`: тот же барьер/easing,
   но слайд снизу вместо zoom-in по центру, прижат к низу экрана,
   `maxHeightFraction` по умолчанию 0.75).
5. `server_list_panel.dart` — разделён на `ServerListPanel` (тонкая обёртка:
   `Container(width: 260, ...)`) и `ServerListContent` (вся реальная логика
   списка без фиксированной ширины) — второй переиспользуется и боковой
   панелью, и bottom sheet'ом. `ServerListContent.onAfterSelect` — колбэк,
   которым bottom sheet закрывает сам себя (`Navigator.pop`) сразу после
   выбора сервера/варианта; в боковой панели не передаётся (там закрывать
   нечего).

**Не сделано в этом шаге** (сознательно, чтобы не тащить весь трек за один
проход):

- **Тайтлбар без кнопок на мобильной раскладке** (п.3 из исходного плана) —
  не реализовано вообще: `AppTitleBar` в `main.dart` не завязан на ширину и
  всегда показывает полный набор кнопок (свернуть/развернуть/закрыть/
  настройки), что и требовалось для resize-сценария на Windows. Разделение
  "нет тайтлбара, кнопка настроек плавает сверху справа" — только для
  реальной мобильной платформы, которой пока нет, чтобы на ней проверить;
  реализовывать это сейчас означало бы писать неработающую в проверке
  ветку по `Platform.isWindows`.
- ~~`SettingsPage`/`SubscriptionInfoPanel` не адаптированы~~ — донастроено
  после жалобы пользователя: `settings_page.dart` на мобильной ширине
  (`isMobileLayout`) заменяет боковой нав (200px, не помещался рядом с
  контентом) на пошаговую навигацию — сперва список секций на весь экран
  (переиспользует `_SettingsNavItem` в `ListView`), тап открывает секцию на
  весь экран со своей мини-шапкой "← Название"; `_SettingRow` (ярлык +
  `PortSelect`) на мобильной ширине переключается с `Row` на `Column`
  (ярлык сверху, контрол под ним), иначе `PortSelect`'s `minWidth: 140`
  переполнял строку. `subscription_info_panel.dart` — весь контент обёрнут
  в `SingleChildScrollView` (раньше не был — на узких/невысоких окнах
  переполнялся по вертикали, там много секций: инфо-строки, скрытые
  серверы, роутинг, кастомные поля из трека 14). Диалоги (`PortDialog`),
  роутинг, импорт подписки — по-прежнему не адаптированы, не были частью
  этой жалобы.
- `maximumSize` по-прежнему не задан (TV/fullscreen сценарий), широкая
  раскладка не пересматривалась — контент как был центрирован
  `maxWidth`-констрейнтами (`ConnectPanel` `maxWidth: 340` и т.п.), так и
  остался, пустое пространство по бокам на большом экране не убиралось.

Проверить вручную (не проверялось — resize/визуальные сценарии, см.
`CLAUDE.md`): resize окна от 320px до fullscreen на одном запущенном
инстансе — где ломается (`SettingsPage`/диалоги на узкой ширине наверняка
переполняются, раз не адаптированы); сама мобильная раскладка
`ConnectionScreen` — кнопка списка открывает bottom sheet, выбор сервера в
нём закрывает лист и применяется на главном экране, кнопка не наезжает на
карточку сервера при длинных именах.

---

## 17. CI: автосборка релиза при бампе версии — сделано

`.github/workflows/release.yml`, триггер — push в `master`, задевающий
`pubspec.yaml`.

1. `check-version` (ubuntu, дешёвый) — достаёт `version:` из `pubspec.yaml`
   (без `+build`-суффикса) и через `gh release view v<version>` проверяет,
   существует ли уже такой релиз. Если да — `should_release=false`, сборка
   не запускается (обычные пуши в master без бампа версии проходят мимо,
   не гоняя полную Windows-сборку каждый раз).
2. `build-windows` (windows-latest, только если `should_release=true`):
   - `scripts/fetch_xray.ps1` / `scripts/fetch_sing_box.ps1` — те же
     скрипты, что и для локальной сборки, тянут бинарники ядер перед
     `flutter build windows`, чтобы `windows/CMakeLists.txt`'s
     `install()`-правила подхватили их в `Release`-папку.
   - `flutter build windows --release` — один и тот же build использован и
     для portable-zip, и для установщика (CMake install-таргет уже
     прогоняется внутри, отдельно ничего не собирается дважды).
   - Portable — `Compress-Archive` всей `Release`-папки в
     `Flux-<version>-windows-portable.zip`.
   - Установщик — Inno Setup **не предустановлен** на `windows-latest`
     (проверено: issue в `actions/runner-images` до сих пор открыт с
     просьбой добавить), ставится через `choco install innosetup`
     (chocolatey на раннере есть из коробки), дальше вызывается тот же
     `windows/installer/flux.iss` из трека 13 через `ISCC.exe
     /DAppVersion=...`.
   - `gh release create v<version>` — публикует релиз с обоими файлами и
     автосгенерированными notes (`--generate-notes`).

Не проверено реальным пушем версии (только синтаксис workflow) — трек 13
(сам `.iss`-скрипт) тоже до сих пор не проверен локальной компиляцией, так
что первый реальный релиз через этот CI будет заодно первой проверкой
обоих треков разом.

---

## 18. Светлая тема + локализация RU/EN — сделано

**Апдейт:** светлая тема залочена на Dark — визуально недоработана
(в частности `accent`, см. ниже), доводить её сейчас не стали. Дефолт
`themeMode` — `dark` (был бы `system` через `fromJson`, теперь тоже `dark`,
согласовано с дефолтом конструктора). Селектор в `settings_page.dart`
показывает только вариант "Тёмная" (тот же приём, что у "Ядро TUN-режима" —
единственный вариант в списке), `main.dart` хардкодит
`PortBrightness.current = Brightness.dark` независимо от
`settings.themeMode` — сам switch по `AppThemeMode` закомментирован рядом,
не удалён, раскомментировать, когда светлую тему доведут. Локализация
(трек ниже) эта пометка не касается — она осталась как есть, полностью
рабочая.

### Светлая тема

`AppThemeMode` (system/light/dark) существовала в настройках и раньше, но
не была подключена — вся палитра в `PortColors`
(`lib/widgets/port_ui/port_tokens.dart`) была захардкожена под тёмную.
Переключение сделано без протаскивания `context`/`Theme.of` через весь
`port_ui` (там ~40+ мест обращаются к `PortColors.xxx`/`PortText.xxx` как к
статическим геттерам) — вместо этого:

1. `lib/widgets/port_ui/port_theme.dart` — `PortBrightness.current`,
   глобальный статический `Brightness`.
2. `main.dart`, `_FluxAppState.build()` — вычисляет эффективную яркость
   (`AppThemeMode.system` → `View.of(context).platformDispatcher.platformBrightness`,
   иначе прямое значение) и присваивает `PortBrightness.current`
   синхронно перед сборкой поддерева — весь дочерний UI в этом же кадре
   уже видит новое значение. `WidgetsBindingObserver.didChangePlatformBrightness`
   триггерит `setState` для смены системной темы на лету.
3. `PortColors` — каждое поле стало `static Color get xxx => _isLight ? ... : ...`,
   тёмные значения не тронуты, светлые — та же shadcn/ui `neutral`
   OKLCH-палитра (`:root`, не `.dark`), пересчитанная тем же способом.
   Исключение — `accent` светлой темы: взят чуть темнее `secondary`/`muted`
   по аналогии с тёмной (там тоже не совпадает с ними) — на глаз, без
   точного OKLCH-пересчёта, можно поправить при визуальной сверке.
4. Побочный эффект: ~10 мест, где `PortColors.xxx` использовался внутри
   `const` конструкторов (`const TextStyle(color: PortColors.foreground)` и
   т.п.), перестали компилироваться — геттер не константа. Везде убран
   `const` у обёртки; `PortSwitch.trackBaseColor` стал `Color?` (был
   `= PortColors.background` значением по умолчанию параметра — тоже
   должно быть константой).
5. Шейдерные фоны (Galaxy/Color Bends/градиент) на главном экране — не
   тронуты, решили не адаптировать под тему (это отдельная творческая
   задача, не часть UI-темизации).

### Локализация RU/EN

Свой модуль (без ARB/gen-l10n/пакетов) — по образцу `PortText`/`PortColors`,
тот же паттерн, что и `port_ui` (собственный порт shadcn/ui вместо пакета —
не из-за экономии на зависимостях, а потому что готовые пакеты были так
себе по качеству).

1. `AppSettings.language` (`AppLanguage { system, ru, en }`, дефолт
   `system`) — тот же паттерн, что `themeMode`.
2. `lib/l10n/app_locale.dart` — `AppLocale.effective` (`AppLanguage`, уже
   не `system`), обновляется в `main.dart` рядом с `PortBrightness.current`:
   `system` резолвится в `ru`/`en` по `View.of(context).platformDispatcher.locale.languageCode`.
   `WidgetsBindingObserver.didChangeLocales` триггерит rebuild при смене
   системной локали на лету.
3. `lib/l10n/strings.dart` — класс `S`, статические геттеры/функции,
   RU/EN пара на каждую строку, сгруппированные комментариями по
   экрану/файлу-источнику (~15 файлов, ~150 строк:
   `connect_panel.dart`, `tray.dart`, `server_list_panel.dart`,
   `server_row.dart`, `subscription_info_panel.dart`,
   `import_subscription_sheet.dart`, `routing_rules_dialog.dart`,
   `settings_page.dart` (крупнейший), `clipboard_import_hotkey.dart`,
   `subscription_import.dart`, `connection_controller.dart`, плюс по ходу
   нашлись ещё пользовательские строки не в изначальной инвентаризации:
   `vless_link_parser.dart`/`hysteria2_link_parser.dart` (сообщения
   `FormatException`, всплывающие как `LinkImportFailure.reason`),
   `apply_mj_payload.dart` (сводка для тоста), `tun_bridge_engine.dart`
   (`StateError`, если TUN стартует без прав администратора)).
4. Не переводится: имена серверов/подписок (данные, не литералы),
   протокольные/технические токены (TCP, ICMP, sing-box, xray-core,
   Magic JSON, DNS, HTTP, UAC, `Simple Gradient`/`Color Bends`/`Galaxy` —
   имена шейдерных фонов), селектор Off/Proxy/TUN
   (`off_proxy_tun_selector.dart` — там и так английские литералы,
   независимо от языка интерфейса), названия языков в самом селекторе
   языка (`Русский`/`English` показываются на родном языке всегда).
   Сознательно не тронуты (см. `import_result.dart`/`ImportSkipped.reason`
   в `base64_subscription_parser.dart`/`xray_subscription_parser.dart`) —
   список пропущенных при импорте серверов нигде в UI сейчас не
   отображается, переводить нечего показывающее пользователю.
5. Склонения (правило/правила/правил, день/дня/дней в
   `subscription_info_panel.dart`) — существующие приватные хелперы
   расширены веткой на `AppLocale.effective == AppLanguage.en` (простая
   английская форма `1 rule`/`N rules`), а не централизованы в `S`.
6. `settings_page.dart` — новый `PortSelect<AppLanguage>` в секции
   "Персонализация" рядом с темой, тот же `_SettingRow`.

Проверено: `flutter analyze` (0 замечаний), `flutter test` (86/86,
`test/widget_test.dart` обновлён — язык в пресете настроек теперь задан
явно (`AppLanguage.ru`), иначе тест зависел бы от локали тестового
окружения). Не проверено вживую (см. `CLAUDE.md`) — переключить
тему/язык в настройках и глазами сверить обе темы (тёмная должна выглядеть
пиксель-в-пиксель как раньше) и оба языка на всех экранах.

## 19. Android-порт — в процессе (ветка `android`)

Отдельная ветка `android`, не смёржена в `master`. План (архитектура
движка) — `C:\Users\local\.claude\plans\resilient-wandering-puddle.md`.

На Windows протокол (VLESS/Hysteria2) всегда обрабатывает xray-core,
sing-box — только Windows-специфичная TUN-обвязка (см. трек про
`TunBridgeEngine`/`docs/fix_tun/`). Рассматривали чистый sing-box на
Android (есть официальная `libbox` AAR с готовой VpnService-интеграцией,
на ней NekoBox/sing-box-for-android) — отклонили: у стокового sing-box
нет XHTTP-транспорта (нужен для VLESS XHTTP/Reality), только у неофициальных
форков с известными багами.

Решение: xray-core остаётся единственным протокольным движком и на
Android — как и на десктопе. Собирается в `.aar` через `gomobile bind`
поверх [2dust/AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite)
(тот же путь, которым v2rayNG собирает xray-core под Android — обычного
предсобранного AAR от самого XTLS нет). Выяснилось, что у xray-core есть
собственный `tun`-инбаунд с gVisor netstack (`proxy/tun`, включая
`tun_android.go`) — он сам читает TUN fd (через env `xray.tun.fd`) и
маршрутизирует пакеты, отдельный tun2socks-мост (как предполагалось
исходно) не нужен. Чтобы не зациклить трафик (xray подключается к своему
же серверу через TUN) — тот же приём, что и в `route_exclude_address` у
sing-box на Windows, но через явное покрытие 0.0.0.0/0 CIDR-блоками без
исключённого IP сервера (`RouteExclusion.kt`, т.к. `Builder.excludeRoute()`
есть только с API 33).

Сделано (Phase 1 + 2 из плана):

1. `flutter create --platforms=android`, `applicationId` = `rip.freeinternet.flux`.
2. `scripts/build_android_xray.ps1` — собирает `libv2ray.aar`
   (android/arm64, `-androidapi 24`) в `android/app/libs/` (не в git, см.
   `android/app/libs/SOURCE.md`, тот же приём, что у `fetch_xray.ps1`/
   `fetch_sing_box.ps1`, но именно сборка, а не скачивание).
3. `FluxVpnService.kt` — `VpnService`, поднимает TUN (адрес/DNS/маршруты
   через `RouteExclusion`), передаёт fd в `CoreController.startLoop`.
4. `MainActivity.kt` — `MethodChannel "flux/vpn"` (`preparePermission`,
   `start`, `stop`), permission-flow через `VpnService.prepare()` +
   `startActivityForResult`.

**Не сделано:** Dart-сторона (`XrayEngineAndroid implements CoreEngine`,
конфиг с `tun`-инбаундом, подключение к `ConnectionController`/UI) — Phase
3 плана, ничего из Flutter-кода пока не вызывает `flux/vpn` канал.
Проверено только `flutter build apk --debug` и `flutter analyze` (чисто) —
живьём на устройстве/эмуляторе не проверялось и не будет проверяться
мной (см. `CLAUDE.md`, "не тести proxy/tun режим в приложении сам") —
нужна проверка руками, когда дойдём до реального подключения.

**Апдейт (Phase 3):** `XrayEngineAndroid implements CoreEngine`
(`lib/engines/xray/xray_engine_android.dart`) подключён к
`ConnectionController` — на Android любой режим (Off/Proxy/TUN, селектор
пока общий для всех платформ, конвергенция UI — Phase 4) идёт через него,
т.к. отдельного Proxy-механизма на Android нет (см. контекст плана).
`buildXrayTunConfig` в `xray_config_mapper.dart` — `tun`-инбаунд вместо
SOCKS/HTTP, переиспользует существующие `_outbound`/`_routing` как есть.
Адрес сервера резолвится в Dart (`InternetAddress.lookup`, тот же приём,
что в `tun_bridge_engine.dart`) до передачи в Kotlin — `RouteExclusion`
там принимает только IPv4-литерал. `flutter analyze`/`flutter test`
(86/86, десктопный путь ветвится через `Platform.isAndroid` и не
затронут)/`flutter build apk --debug` — чисто. Не проверено на
устройстве — то же ограничение, что и у Phase 2.

**Апдейт (живое тестирование на Pixel 6a, через `adb`):** нашли и
исправили четыре независимых бага, ни один не ловится
`flutter analyze`/`flutter test`/сборкой — только реальным подключением:

1. **Чёрный экран при запуске.** `main.dart` дергал `windowManager.
   ensureInitialized()` без проверки платформы (`window_manager` —
   desktop-only пакет) — необработанное исключение до `runApp()`, весь
   `main()` обрывался, `runApp` не вызывался. Обернули все вызовы
   `window_manager` в `main.dart`/`_FluxAppState` в `Platform.isWindows`
   (`tray.dart`/`deep_link.dart` уже были самодостаточны в этом смысле).
2. **`geosite.dat`/`geoip.dat` не находятся.** xray-core резолвит путь к
   ним через `os.Stat` **до** вызова `NewFileReader`-хука
   (`common/platform/filesystem.getAssetFileLocation`) — значит,
   `InitCoreEnv`/`Seq.setContext` (JNI-мост в `golang.org/x/mobile/asset`)
   тут в принципе не помогают, т.к. `mobasset.Open` до них просто не
   доходит. Единственный рабочий вариант — распаковать оба файла из
   Android-ассетов (они реально попадают в APK из `libv2ray.aar`, но
   только через `AssetManager`, не как обычный путь) в `filesDir` при
   старте сервиса (`FluxVpnService.ensureGeoAssetsExtracted()`) и указать
   `xray.location.asset` туда явно.
3. **DNS-петля / зависшие коннекты к серверу.** `XrayEngineAndroid`
   резолвил адрес сервера в Dart только чтобы построить маршруты
   исключения — сам конфиг xray по-прежнему получал исходный хостнейм, и
   xray-core резолвил его заново уже своим DNS-запросом, который уходил в
   тот же ещё не поднятый тоннель (тот самый deadlock "нужен тоннель,
   чтобы поднять тоннель" из `tun_bridge_engine.dart`, но не
   предотвращённый на Android). В логах это выглядело как бесконечные
   `dialing TCP to <хост>:<порт>` без единого завершения. Фикс —
   `XrayEngineAndroid._pinToResolvedIp`: подставляет уже резолвленный IP
   как адрес подключения в конфиге, `sni`/`xhttpHost` фиксирует на
   исходном хостнейме явно (иначе TLS/Reality SNI станет IP и хендшейк не
   пройдёт).
4. **Доменные routing-правила не применялись, `direct`-маршрут для них
   тоже приводил к зависанию.** TUN — чистый L3, без sniffing
   `DomainRule` в принципе не может сработать (виден только IP пакета) —
   добавили `sniffing: {enabled: true, destOverride: [...], routeOnly:
   true}` на `tun`-инбаунд в `buildXrayTunConfig` (тот же приём, что
   `action: "sniff"` у sing-box на Windows). После этого всплыл второй
   слой той же проблемы, что и в п.3: `direct`-outbound сам коннектится к
   произвольному IP сайта, который в маршруты-исключения не попадает —
   тоже уходил в тот же тоннель и зависал. Настоящий фикс —
   `Builder.addDisallowedApplication(packageName)` в
   `FluxVpnService.startTunnel` — исключает вообще всё, что коннектит сам
   xray-core (не только к VLESS-серверу, а вообще), из собственного
   VPN-тоннеля приложения; `RouteExclusion` после этого уже не
   единственная защита от петли, а подстраховка.

После всех четырёх фиксов: подключение поднимается, прокси-трафик реально
идёт через VLESS-сервер, `direct`-правила по доменам срабатывают
(проверено на `2ip.ru`) — живой тест пользователем подтвердил рабочее
состояние.

**Апдейт (Phase 4 — UI-адаптация под мобильную раскладку):**

1. `windows_elevation.dart` (`DynamicLibrary.open('shell32.dll')`) падал
   бы при первом же тапе на "TUN" на Android — `connect_panel.dart`
   теперь ветвится по `Platform.isAndroid` до вызова `isRunningElevated()`
   вообще. Селектор `OffProxyTunSelector` схлопнут в Off/On
   (`simplifiedOnOff`) — сегмент "Proxy" скрыт, TUN-сегмент подписан "On"
   и покрашен в зелёный (не в синий — так приятнее), оба сегмента шире,
   чтобы не выглядеть неряшливо вдвоём вместо троих.
2. `AppTitleBar` (drag-area, minimize/maximize/close — `window_manager`,
   desktop-only) не рендерится на Android вообще (`main.dart`) — доступ к
   настройкам вместо этого дают плавающей кнопкой-шестерёнкой сверху
   справа в `ConnectionScreen` (мобильная раскладка), симметрично уже
   существовавшей кнопке списка серверов слева. `SettingsPage` (у неё
   своя шапка с "назад") и обе плавающие кнопки на `ConnectionScreen`
   получили `SafeArea`/отступ на `MediaQuery.padding.top` — без
   `AppTitleBar` они иначе рисуются прямо под статус-баром/чёлкой.
3. `settings_page.dart`: секции "TUN" (там всегда список из одного
   sing-box, а Android использует свой `tun`-инбаунд xray-core, не
   sing-box вовсе) и "Система" (автозапуск — тихий no-op на Android, см.
   `windows_autostart.dart`) скрыты через `_visibleSettingsSections`.
4. `port_bottom_sheet.dart` (список серверов на мобильной раскладке) был
   обычным `showGeneralDialog` без единого жеста — палец интуитивно тянет
   такой лист вниз, а ничего не происходило. Добавили drag-to-dismiss, но
   не на весь лист целиком: список внутри (`ServerListContent`, тот же
   виджет, что и в десктопной `ServerListPanel`, трогать нельзя) сам
   скроллящийся, и общий `GestureDetector` проигрывает гонку жестов
   вложенному `Scrollable`. Пробовали ловить "докрутили до верха, тянут
   дальше" через `NotificationListener<ScrollNotification>` +
   `BouncingScrollPhysics` (чтобы получить `OverscrollNotification`) — не
   сработало: списки в приложении почти всегда длиннее видимой области
   листа, палец успевает просто проскроллить контент, не долетая до
   overscroll за один свайп (подтверждено логами — ни разу не пришёл
   `OverscrollNotification`, только `ScrollUpdateNotification`).
   Остановились на отдельной полоске-ручке сверху (32px, с ручкой видимой
   4px-полоской) — работает надёжно, устроило при живой проверке.
5. `proxy_tree_list.dart`: drag-and-drop сервера/группы между узлами дерева
   был на обычном `Draggable` — стартовал перетаскивание с первого же
   движения пальца, на тачскрине это означало случайные сдвиги при
   попытке просто скроллить/тапнуть. На `Platform.isAndroid ||
   Platform.isIOS` заменили на `LongPressDraggable` (тот же виджет с
   задержкой перед стартом) — десктопная мышь по-прежнему тащит сразу,
   без изменений.

Всё проверено живьём на Pixel 6a (`flutter analyze`/`flutter test`
86/86 — тоже чисто, десктопный путь везде за `Platform.isWindows`/
`Platform.isAndroid` не тронут).
