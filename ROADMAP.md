# ROADMAP.md — ближайшее развитие

Рабочий бэклог поверх PLAN.md: что доделываем прямо сейчас, в каком порядке
и какими шагами. PLAN.md — архитектура и продуктовое видение, этот файл —
текущий срез задач, правится по ходу работы (вычёркиваем сделанное,
дописываем новое).

Порядок реализации:

0. ~~Мерж состояния при рефреше подписки~~ — сделано
   (`merge_subscription_tree.dart`, см. ниже)
1. Hysteria2
2. Скрытие серверов
3. Роутинг (per-server + bulk на подписку)
4. Пинг
5. Авто-режим
6. Drag-and-drop сортировка
7. Трей + автозапуск
8. Фон — шейдерные эффекты (Color Bends → Galaxy)

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

## 4. Пинг

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

## 5. Авто-режим как узел Magic JSON

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

## 6. Drag-and-drop сортировка серверов/групп

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

## 7. Трей-иконка и автозапуск

**Закрытие окна (✕) сворачивает в трей** (подтверждено) — полный выход
только через пункт "Выход" в меню трея.

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

## 8. Фон — шейдерные эффекты (Color Bends → Galaxy)

Оба взяты с [reactbits.dev](https://reactbits.dev) (react-bits, MIT,
[github.com/DavidHDev/react-bits](https://github.com/DavidHDev/react-bits),
папка `Backgrounds`). Оба реализованы там как WebGL fragment-шейдеры
(Color Bends — Three.js, Galaxy — OGL) — это ровно то, что умеет нативно
Flutter через `dart:ui` fragment shaders (`.frag`, компилируется `impellerc`,
рисуется через `FragmentShader` + `CustomPainter`), так что порт — это
построчный перенос GLSL-математики, а не переизобретение рендера.

**Порядок: Color Bends → Galaxy** — Color Bends проще (нет процедурной
генерации точек, только цветовые полосы через domain warping — сумма
синусоид), хороший первый шейдер, чтобы обкатать сам pipeline интеграции
шейдеров в приложении на Windows. Galaxy сложнее (~300 строк,
hash-based процедурная генерация звёзд, 4 слоя глубины для параллакса,
мерцание через треугольную волну по времени) — делаем вторым, тем же
способом.

**Быстрый прототип Color Bends уже накидан** для оценки (не подключён к
настройкам, просто временно воткнут в `connection_screen.dart` поверх
`Starfield`):
- `shaders/color_bends.frag` — построчный порт `ColorBends.tsx` (упрощено:
  фиксированные 3 цвета/параметры вместо настраиваемых uniform'ов
  оригинала).
- `lib/widgets/globe/color_bends_background.dart` — `FragmentProgram.fromAsset`
  + `CustomPainter`, `uTime` двигает `Ticker`.
- `pubspec.yaml` — секция `flutter: shaders:`.

Шаги до полноценной интеграции (когда определимся, что оставляем):
1. Вынести захардкоженные параметры шейдера (цвета, ITERATIONS, FREQUENCY,
   WARP_STRENGTH, BAND_WIDTH, INTENSITY) в uniform'ы — сейчас зафиксированы
   в `.frag` для скорости прототипа.
2. `HomeBackground` (`app_settings.dart`) — добавить варианты `colorBends`/
   `galaxy` рядом с `none`/`globe`; `settings_dialog.dart` — добавить их в
   `ShadSelect`.
3. `connection_screen.dart` — `showGlobe`-переключатель заменить на общий
   `switch` по `HomeBackground`, вместо временной прямой вставки
   `ColorBendsBackground` поверх `Starfield`.
4. Портировать Galaxy тем же способом (`shaders/galaxy.frag` +
   виджет-обёртка), уже с нормальными uniform'ами с самого начала (раз
   pipeline обкатан на Color Bends).
5. Проверить производительность/нагрев на слабом железе — фон рисуется
   каждый кадр на весь экран, стоит проверить, не роняет ли это FPS
   остального UI поверх (список серверов и т.п.) на реальном ноутбуке, не
   только на разработческой машине.
