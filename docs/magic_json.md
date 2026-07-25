# Magic JSON — формат профиля Flux

Этот документ — контракт для внешнего сервиса, который хочет генерировать
конфигурацию специально под клиент Flux: что отдавать по URL подписки,
какие HTTP-заголовки Flux понимает, и как внутри устроен профиль (Magic
JSON, далее — MJ), в который всё это превращается на клиенте.

Если коротко: **не нужно генерировать сам Magic JSON** — Flux не умеет
импортировать его напрямую по URL (MJ существует только как файл на диске
пользователя, `%AppData%\flux\profile.json`, недоступный снаружи). Сервис
подписки должен отдавать обычный **xray-json** (или список ссылок
`vless://`/`hysteria2://`) — Flux сам конвертирует это в MJ при импорте.
Схема MJ описана ниже как справочная информация — она объясняет, во что
превратится присланная подписка и что клиент хранит между запусками.

## 1. Что должен отдавать URL подписки

Пользователь (или сам сервис через deep link/QR) добавляет в Flux один
URL. При добавлении и на каждом рефреше Flux делает `GET` по этому URL и
разбирает ответ.

### 1.1 Тело ответа

Поддерживаются два формата, автоопределение по первому непробельному
символу тела:

- **xray-json** (тело начинается с `{` или `[`) — рекомендуемый формат,
  единственный поддерживает `routing`. Один объект или массив объектов —
  по одному на сервер:

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
  legacy-алиас) — имя сервера; см. §3 про группировку по имени.

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
  подписке целиком (в MJ это поле `ServerLeaf.routingRules`, см. §4.3).

- **База из ссылок** (тело не начинается с `{`/`[`) — список
  `vless://...`/`hysteria2://...`(алиас `hy2://`) построчно, всё тело
  целиком закодировано в base64/base64url (как отдают 3x-ui/Marzban и
  т.п.). Если base64-декодирование не удаётся, тело используется как
  обычный текст со ссылками. Простой формат для совместимости — **не
  поддерживает** `routing`, кастомные поля и точную группировку. Для
  сервиса, который специально генерирует конфиг под Flux, xray-json
  предпочтительнее.

### 1.2 HTTP-заголовки ответа

Все — опциональны, разбираются регистронезависимо.

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

### 1.3 Обновление существующих серверов между рефрешами

Единственный стабильный идентификатор сервера между рефрешами — **пара
адрес+порт первого варианта** (`ServerConfig.address`/`port`). Ротация
UUID/пароля на сервере с тем же адресом:порт долетит до клиента как
обновление существующего сервера (сохранит `hidden`, ручной выбор,
позицию в дереве). Если адрес или порт меняются — с точки зрения клиента
это уже другой сервер (старый пропадёт из списка при следующем рефреше,
новый добавится).

## 2. Группировка серверов по имени

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

## 3. Несколько вариантов подключения на одном сервере

Если один физический сервер поддерживает несколько
протоколов/транспортов (TCP+Reality, XHTTP+Reality, Hysteria2 — как
видно на скриншотах Flux, где у сервера есть переключатель "Hysteria2 /
TCP Reality / XHTTP Reality"), сейчас Flux **не объединяет их
автоматически** при импорте из xray-json — каждый outbound-объект в
массиве подписки становится отдельным `ServerLeaf`. Объединение
вариантов в один `ConnectionVariant[]` на одном `ServerLeaf` (см. §4.3)
происходит только при мерже дерева между рефрешами по совпадению
адрес:порт — то есть если сервис хочет явно показать несколько вариантов
одного сервера как один элемент списка, эта возможность пока не
проброшена во внешний формат подписки. Отслеживается в ROADMAP.md.

## 4. Схема Magic JSON (внутреннее хранение)

Справочно — во что превращается импортированная подписка и что живёт в
`profile.json`. `schemaVersion` — обязательное поле, сейчас `1`;
несовпадение версии кидает ошибку при загрузке (миграций между версиями
пока нет — см. `core_config.dart`). Если в будущем появится способ
завозить MJ напрямую, версия должна совпадать буквально.

### 4.1 `CoreConfig` — корень

```json
{
  "schemaVersion": 1,
  "subscriptions": [ /* Subscription[] — см. §4.2 */ ],
  "standaloneNodes": [ /* ProxyNode[] — серверы вне подписок, см. §4.3 */ ]
}
```

### 4.2 `Subscription`

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
  "root": { /* ProxyNode — обычно ServerGroup, см. §4.3 */ }
}
```

Все поля, кроме `id`/`name`/`url`/`root`, опциональны и полностью
заменяются на каждом рефреше (§1.3).

### 4.3 `ProxyNode` — дерево серверов/групп

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
  клиент сам вставляет его первым элементом в каждую группу при импорте
  (см. §2) — генерировать его в подписке не нужно, он не несёт
  подключения сам по себе.

### 4.4 `ConnectionVariant` и `ServerConfig`

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

### 4.5 `RoutingRule`

```json
{ "type": "domain", "values": ["geosite:category-ads", "example.com"], "outboundTag": "block" }
{ "type": "ip", "values": ["geoip:cn", "1.2.3.0/24"], "outboundTag": "direct" }
```

`outboundTag` — `"direct"`/`"block"`/`"proxy"`. `values` — как есть, тот
же синтаксис, что и в xray-json (§1.1).

## 5. Обратная совместимость

Формат MJ версионируется через `schemaVersion` (сейчас `1`). Правило на
будущее (см. PLAN.md): при добавлении нового поля к существующему
типу — делать его опциональным с безопасным дефолтом при отсутствии, не
поднимая `schemaVersion` (клиенты старой версии тогда просто не увидят
новое поле). `schemaVersion` поднимается только при breaking change
(переименование/удаление поля, смена смысла существующего) — на текущий
момент миграций между версиями в коде нет, несовпадение версии полностью
обнуляет профиль при загрузке. Это касается только гипотетического
прямого импорта MJ — заголовки/тело подписки (§1) таким ограничением не
связаны, xray-json как формат сам по себе не версионируется этим полем.
