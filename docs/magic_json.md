# Magic JSON — формат профиля Flux

Этот документ — контракт для внешнего сервиса, который хочет генерировать
конфигурацию специально под клиент Flux: что отдавать по URL подписки,
какие HTTP-заголовки Flux понимает, и как внутри устроен профиль (Magic
JSON, далее — MJ), в который всё это превращается на клиенте.

**Если сервис знает про Flux — генерируйте сам MJ напрямую** (§1), это и
есть основной сценарий, под который MJ проектировался. Xray-json/base64
(§2) остаются как fallback-форматы для панелей, которые ничего не знают о
Flux (3x-ui, Marzban и т.п.) — Flux их тоже понимает, но это конвертация
"снаружи", а не нативный формат.

## 1. Magic JSON напрямую по URL подписки (рекомендуется)

Единица передачи по одному URL — **не весь профиль** (`CoreConfig` — это
локальное хранилище на диске пользователя, `%AppData%\flux\profile.json`,
там сразу много подписок + standalone-узлы вперемешку, отдавать это одним
HTTP-ответом незачем и странно). Единица передачи — конверт с явным типом
содержимого:

```json
{
  "schemaVersion": 1,
  "type": "subscriptions",
  "content": [ /* Subscription[], см. §3.2 */ ]
}
```

```json
{
  "schemaVersion": 1,
  "type": "nodes",
  "content": [ /* ProxyNode[], см. §3.3 */ ]
}
```

- **`type: "subscriptions"`** — `content` — массив полных объектов
  `Subscription` (обычно один элемент — сервис отдаёт "мою подписку", но
  можно прислать сразу несколько, например разные тарифы одного аккаунта
  на один и тот же URL). Каждый элемент — самодостаточный: id, дерево
  серверов, трафик, срок действия, кастомные поля — всё уже в нужной
  клиенту форме, конвертировать через xray-json не нужно.
- **`type: "nodes"`** — `content` — плоский массив `ProxyNode` (лист или
  группа) без подписки-обёртки, аналог standalone-серверов, добавленных
  вручную. Не участвует в обычном цикле "рефреш подписки" (см. ниже) —
  это одноразовый импорт набора серверов.

Flux определяет этот формат по телу ответа: JSON-объект с ключами
`schemaVersion`/`type`/`content` на верхнем уровне (у xray-json там
`remarks`/`outbounds`, различить легко). HTTP-заголовки из §2.2
(`Subscription-Userinfo` и т.п.) для этого формата **не нужны и
игнорируются** — все те же данные (`traffic`, `expiresAt`,
`customFields`, `annotation`) уже поля самого `Subscription`-объекта,
см. §3.2.

### 1.1 Добавление и рефреш

- **Первое добавление** (пользователь вставил URL в диалог "Добавить
  сервер", либо Ctrl+V, либо `flux://add/...` deep link) — Flux
  добавляет каждый элемент `content` как новую подписку/новые
  standalone-узлы.
- **Повторное добавление того же URL** (или рефреш существующей
  подписки) — для `type: "subscriptions"` элементы сопоставляются с уже
  существующими подписками **по `Subscription.id`**: совпал id — дерево
  сервера мержится тем же способом, что и при рефреше xray-json-подписки
  (сохраняет `hidden`/ручной выбор/порядок, см. §2.3), метаданные
  (`traffic`/`expiresAt`/`customFields`/`annotation`) заменяются
  свежими; не совпал ни с одной — добавляется как новая подписка. Кнопка
  "Обновить" на странице конкретной подписки повторно запрашивает тот же
  URL и обновляет только тот элемент `content`, чей `id` совпадает с
  этой подпиской (если сервис вернул сразу несколько — остальные
  элементы конверта в этом точечном рефреше не участвуют, только
  первое/пакетное добавление обрабатывает их все разом).
- Для `type: "nodes"` id тоже стабилизирует апдейт: узел с уже
  существующим `id` среди standalone-узлов заменяется целиком (позиция
  сдвигается в конец списка), новый `id` — дописывается.

**`id` — то, что должен генерировать и стабильно переиспользовать сам
сервис** (не Flux) — раз именно по нему происходит сопоставление
"это тот же объект, что и раньше" между запросами. Смена `id` между
рефрешами воспринимается как "старое удалено, новое добавлено" —
теряется `hidden`/сортировка/ручной выбор варианта.

## 2. Fallback: xray-json / base64-подписка

Для панелей, которые не умеют в MJ — Flux понимает и этот формат, тело
ответа на тот же URL подписки.

### 2.1 Тело ответа

Поддерживаются два формата, автоопределение по первому непробельному
символу тела:

- **xray-json** (тело начинается с `{` или `[`, и это не MJ-конверт из
  §1) — единственный из двух fallback-форматов поддерживает `routing`.
  Один объект или массив объектов — по одному на сервер:

  ```json
  [
    {
      "remarks": "Basic - Germany 1",
      "outbounds": [
        {
          "protocol": "vless",
          "settings": {
            "vnext": [
              {
                "address": "de1.example.com",
                "port": 443,
                "users": [{ "id": "1f9a2b3c-...", "flow": "" }]
              }
            ]
          },
          "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
              "serverName": "www.microsoft.com",
              "publicKey": "abcDEF...",
              "shortId": "0a1b2c",
              "fingerprint": "chrome"
            }
          }
        },
        { "protocol": "freedom" }
      ],
      "routing": {
        "rules": [
          {
            "type": "field",
            "domain": ["geosite:category-ads", "example-blocked.com"],
            "outboundTag": "block"
          },
          { "type": "field", "ip": ["geoip:cn"], "outboundTag": "direct" }
        ]
      }
    },
    {
      "remarks": "Premium - Sweden 1 Hysteria2",
      "outbounds": [
        {
          "protocol": "hysteria",
          "settings": { "address": "se1.example.com", "port": 8443 },
          "streamSettings": {
            "security": "tls",
            "tlsSettings": { "serverName": "se1.example.com" },
            "hysteriaSettings": {
              "auth": "shared-secret",
              "obfs": { "type": "salamander", "password": "optional" }
            }
          }
        },
        { "protocol": "freedom" }
      ]
    }
  ]
  ```

  Первый non-`freedom`/`blackhole` outbound берётся как сервер. Только
  `protocol: "vless"` и `protocol: "hysteria"` (это Hysteria2 — xray-core
  так называет протокол, обязательно версия 2) распознаются, остальные
  пропускаются с причиной, видимой в UI импорта. `remarks` (или `ps`,
  legacy-алиас) — имя сервера; см. §4 про группировку по имени.

  Поля VLESS-outbound, которые понимает парсер: `vnext[0].address/port`,
  `users[0].id/flow`, `streamSettings.network` (`tcp`/`xhttp`),
  `streamSettings.security` (`none`/`tls`/`reality`),
  `realitySettings`/`tlsSettings.serverName` → `sni`,
  `realitySettings.publicKey/shortId`,
  `realitySettings.fingerprint`/`tlsSettings.fingerprint`,
  `xhttpSettings.path/host` (если `network: "xhttp"`).

  Поля Hysteria2-outbound: `settings.address/port`,
  `hysteriaSettings.auth`, `tlsSettings.serverName` → `sni`,
  `tlsSettings.allowInsecure` → `insecure`,
  `hysteriaSettings.obfs.password` (только `type: "salamander"`,
  опционально).

  `routing.rules` — массив `{"type": "field", "domain": [...],
  "outboundTag": ...}` / `{"type": "field", "ip": [...], "outboundTag":
  ...}`, один и тот же синтаксис, что понимает xray: голые
  домены/CIDR или `geosite:`/`geoip:`-префиксы вперемешку. Значения не
  интерпретируются, сохраняются как есть. Правила — на **сервере**, не на
  подписке целиком (в MJ это поле `ServerLeaf.routingRules`, см. §3.3).

- **База из ссылок** (тело не начинается с `{`/`[`) — список
  `vless://...`/`hysteria2://...`(алиас `hy2://`) построчно, всё тело
  целиком закодировано в base64/base64url (как отдают 3x-ui/Marzban и
  т.п.). Если base64-декодирование не удаётся, тело используется как
  обычный текст со ссылками. Простой формат для совместимости — **не
  поддерживает** `routing`, кастомные поля и точную группировку. Для
  сервиса, который специально генерирует конфиг под Flux, MJ (§1) или
  хотя бы xray-json предпочтительнее.

### 2.2 HTTP-заголовки ответа (только для xray-json/base64)

Все — опциональны, разбираются регистронезависимо. Не применимы к MJ-
конверту (§1) — там те же данные передаются полями `Subscription` напрямую.

| Заголовок | Формат | На что влияет |
|---|---|---|
| `Subscription-Userinfo` | `upload=<bytes>; download=<bytes>; total=<bytes>; expire=<unix-seconds>` | `Subscription.traffic` (used = upload+download, total), `Subscription.expiresAt` (`expire` — 0 или отсутствует = без срока). Без `total` заголовок игнорируется целиком. |
| `Announce` | `<текст>` или `base64:<base64 UTF-8 текста>` | `Subscription.annotation` — свободный текст под названием подписки в UI (статус аккаунта, объявление и т.п.). |
| `Profile-Custom-Fields` | `base64:<base64 UTF-8 JSON-объекта string→string>` | `Subscription.customFields` — произвольные пары ключ-значение, отображаются на странице подписки построчно, в порядке следования ключей в объекте. Пример: значение `base64:eyJUYXJpZiI6IlByZW1pdW0ifQ==` декодируется в `{"Тариф": "Premium"}`. Без префикса `base64:` заголовок трактуется как обычная строка (декодирование не удастся, поле не заполнится) — префикс обязателен. |

Пример полного набора заголовков ответа:

```
HTTP/1.1 200 OK
Content-Type: application/json
Subscription-Userinfo: upload=1073741824; download=5368709120; total=107374182400; expire=1798761600
Announce: base64:0J/RgNC10LzQuNGD0LwgQWN0aXZl
Profile-Custom-Fields: base64:eyJUYXJpZiI6IlByZW1pdW0iLCAi0KHRgtCw0YLRg9GBIjogItCQ0LrRgtC40LIifQ==
```

(`Profile-Custom-Fields` тут раскодируется в `{"Тариф": "Premium",
"Статус": "Актив"}`.)

Каждый рефреш подписки полностью заменяет `traffic`/`expiresAt`/
`annotation`/`customFields` свежими значениями — это динамические данные
сервиса, не история. Если какой-то из заголовков в ответе отсутствует,
соответствующее поле остаётся пустым (`null`/`{}`), а не сохраняет
значение с прошлого рефреша.

### 2.3 Обновление существующих серверов между рефрешами (xray-json/base64)

В отличие от MJ (где сопоставление идёт по `id`, см. §1.1), у
xray-json/base64 стабильного id нет вообще — единственный стабильный
идентификатор сервера между рефрешами — **пара адрес+порт первого
варианта** (`ServerConfig.address`/`port`). Ротация UUID/пароля на
сервере с тем же адресом:порт долетит до клиента как обновление
существующего сервера (сохранит `hidden`, ручной выбор, позицию в
дереве). Если адрес или порт меняются — с точки зрения клиента это уже
другой сервер (старый пропадёт из списка при следующем рефреше, новый
добавится).

## 3. Схема Magic JSON

`schemaVersion` — обязательное поле что у конверта из §1, что у
`CoreConfig`, сейчас `1`; несовпадение версии — ошибка формата (миграций
между версиями пока нет).

### 3.1 `CoreConfig` — локальное хранилище (не отдаётся по сети)

```json
{
  "schemaVersion": 1,
  "subscriptions": [ /* Subscription[] — см. §3.2 */ ],
  "standaloneNodes": [ /* ProxyNode[] — серверы вне подписок, см. §3.3 */ ]
}
```

Это то, что лежит на диске пользователя
(`%AppData%\flux\profile.json`) после того, как он добавил один или
несколько источников (MJ-конверты из §1, xray-json/base64-подписки из
§2, одиночные `vless://`/`hysteria2://` ссылки). Сервису подписки
генерировать это целиком не нужно — см. §1.

### 3.2 `Subscription`

```json
{
  "id": "uuid",
  "name": "example.com",
  "url": "https://example.com/sub/token",
  "pictureUrl": null,
  "annotation": "Активен до 2026-12-31",
  "traffic": { "usedBytes": 6442450944, "totalBytes": 107374182400 },
  "expiresAt": "2026-12-31T00:00:00.000Z",
  "lastRefreshedAt": "2026-07-25T10:00:00.000Z",
  "autoRefreshOnStartup": false,
  "customFields": { "Тариф": "Premium", "Статус": "Актив" },
  "root": { /* ProxyNode — обычно ServerGroup, см. §3.3 */ }
}
```

Все поля, кроме `id`/`name`/`url`/`root`, опциональны. `id` — см. §1.1
про то, зачем его нужно стабильно переиспользовать. `url` внутри
объекта — тот же URL, по которому сервис отдаёт этот MJ-конверт (Flux
использует его, когда пользователь жмёт "Обновить" на странице
подписки) — можно, но не обязательно, делать его равным входному URL,
если сервис хочет управлять роутингом на своей стороне.

### 3.3 `ProxyNode` — дерево серверов/групп

Sealed-тип, диспетчер по полю `type`:

- **`ServerLeaf`** (`type: "leaf"`) — один сервер:

  ```json
  {
    "type": "leaf",
    "id": "uuid",
    "name": "Germany 1",
    "icon": "🇩🇪",
    "hidden": false,
    "variants": [ /* ConnectionVariant[], см. ниже */ ],
    "selection": { "type": "manual", "variantId": "uuid" },
    "routingRules": [ /* RoutingRule[], см. ниже */ ]
  }
  ```

  `selection` — `{"type": "auto"}` (первый вариант) или `{"type":
  "manual", "variantId": "..."}`. `icon` — любой эмодзи, не обязательно
  флаг (по умолчанию определяется по названию страны в имени, но можно
  передать произвольный). `routingRules: []` = весь трафик сервера идёт
  через прокси без исключений.

- **`ServerGroup`** (`type: "group"`) — вложенная группа:

  ```json
  {
    "type": "group",
    "id": "uuid",
    "name": "Basic",
    "icon": null,
    "hidden": false,
    "strategy": "select",
    "children": [ /* ProxyNode[] — вложенность не ограничена */ ]
  }
  ```

  `strategy` — `select`/`urlTest`/`fallback`/`loadBalance`, сейчас
  реально используется только сам факт "эта группа выбрана через Авто"
  (`urlTest`) для UI, остальные — задел на будущее.

- **`AutoSelectMarker`** (`type: "auto"`) — псевдо-узел "⚡ Авто",
  клиент сам вставляет его первым элементом в каждую группу с
  несколькими серверами (см. §4) — генерировать его самостоятельно не
  нужно, он не несёт подключения сам по себе.

### 3.4 `ConnectionVariant` и `ServerConfig`

```json
{
  "id": "uuid",
  "label": "TCP Reality",
  "config": { /* ServerConfig — см. ниже */ }
}
```

`ServerConfig` — sealed-тип, диспетчер по полю `protocol`:

**`vless`**:

```json
{
  "protocol": "vless",
  "address": "de1.example.com",
  "port": 443,
  "uuid": "1f9a2b3c-...",
  "flow": "xtls-rprx-vision",
  "network": "tcp",
  "security": "reality",
  "sni": "www.microsoft.com",
  "publicKey": "abcDEF...",
  "shortId": "0a1b2c",
  "fingerprint": "chrome",
  "xhttpPath": null,
  "xhttpHost": null
}
```

`network`: `tcp`/`xhttp`. `security`: `none`/`tls`/`reality`. Поля
`sni`/`publicKey`/`shortId`/`fingerprint` — TLS/Reality, `xhttpPath`/
`xhttpHost` — только при `network: "xhttp"`. Все опциональны (кроме
`address`/`port`/`uuid`) и не сериализуются при `null`.

**`hysteria2`**:

```json
{
  "protocol": "hysteria2",
  "address": "se1.example.com",
  "port": 8443,
  "auth": "shared-secret",
  "sni": "se1.example.com",
  "insecure": false,
  "obfsPassword": "optional"
}
```

`insecure` сериализуется только если `true`; `obfsPassword`
опциональна — отсутствие значит без обфускации Salamander.

### 3.5 `RoutingRule`

```json
{ "type": "domain", "values": ["geosite:category-ads", "example.com"], "outboundTag": "block" }
{ "type": "ip", "values": ["geoip:cn", "1.2.3.0/24"], "outboundTag": "direct" }
```

`outboundTag` — `"direct"`/`"block"`/`"proxy"`. `values` — как есть, тот
же синтаксис, что и в xray-json (§2.1).

## 4. Группировка серверов по имени (только xray-json/base64)

Актуально только для fallback-форматов (§2) — MJ-конверт (§1) уже несёт
готовое дерево `ProxyNode`, группировку по имени задаёт сам сервис через
`ServerGroup`, эта логика к нему не применяется.

Если у клиента включена настройка «Автоматическая разбивка по группам»
(включена по умолчанию), `remarks` разбирается по разделителям (пробел,
`-`, `/`, `|`, `,`) на сегменты, и общие сегменты становятся вложенными
группами:

- `"Basic - Germany 1"`, `"Basic - Finland 1"` → группа **Basic**
  (Germany 1, Finland 1).
- `"Premium - Sweden 1"` без других серверов в Premium — группа не
  создаётся ради одного элемента, сервер остаётся плоским листом с именем
  `"Premium Sweden 1"`.
- Голый числовой хвост (`"Basic - Germany - 1"` → сегмент `"1"`)
  дополняется именем ближайшей группы, чтобы не остаться нечитаемым
  номером: `"Germany 1"`.

Если такая разбивка не нужна — сервис может передавать плоские
`remarks` без общих префиксов, тогда группировка не сработает (нет
реального ветвления — см. `group_leaves_by_name.dart`), и все серверы
останутся плоским списком.

## 5. Несколько вариантов подключения на одном сервере

Если один физический сервер поддерживает несколько
протоколов/транспортов (TCP+Reality, XHTTP+Reality, Hysteria2 — как
видно на скриншотах Flux, где у сервера есть переключатель "Hysteria2 /
TCP Reality / XHTTP Reality") — это ровно `ConnectionVariant[]` на одном
`ServerLeaf` (§3.3/§3.4). В MJ-конверте (§1) сервис описывает это явно
сам, положив несколько элементов в `variants`. В xray-json/base64 (§2)
такой возможности нет — каждый outbound-объект в массиве подписки
становится отдельным `ServerLeaf`; объединение вариантов в один список
происходит только задним числом при мерже дерева между рефрешами по
совпадению адрес:порт, не при первом импорте.

## 6. Обратная совместимость

`schemaVersion` — контракт версии формата (сейчас `1` и для конверта из
§1, и для `CoreConfig`). Правило на будущее (см. PLAN.md): при добавлении
нового поля к существующему типу — делать его опциональным с безопасным
дефолтом при отсутствии, не поднимая `schemaVersion` (клиенты старой
версии тогда просто не увидят новое поле). `schemaVersion` поднимается
только при breaking change (переименование/удаление поля, смена смысла
существующего) — на текущий момент миграций между версиями в коде нет,
несовпадение версии полностью отклоняет присланный MJ (ошибка импорта,
существующий профиль не трогается) — соответственно и локальный
`profile.json` с несовпадающей версией тоже не грузится, обнуляется в
пустой профиль. Заголовки/тело fallback-подписки (§2) таким ограничением
не связаны, xray-json сам по себе не версionируется этим полем.
