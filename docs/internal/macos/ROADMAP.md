# macOS-роадмап

Ветка `macos` (от `master`). Разрабатывается на Windows без Mac и без
платного Apple Developer-аккаунта — весь код написан "вслепую" (не
компилировался, не запускался), реальная сборка/тест только на самом Маке
у пользователя, финальный signed-билд — у друга с dev-аккаунтом. См.
CLAUDE.md: proxy/TUN-режим Claude в этом проекте сам не тестирует, ни на
одной платформе.

## Статус: скаффолд + структурный код написаны, ничего не скомпилировано и не проверено

### Сделано

- **Flutter-скаффолд** — `macos/` через `flutter create --platforms=macos .`
  (`Runner.xcodeproj`, `AppDelegate.swift`, `MainFlutterWindow.swift`,
  entitlements, `Info.plist`).
- **Entitlements** — App Sandbox отключён (нужен subprocess xray/sing-box +
  запись вне контейнера), `network.client`/`network.server` добавлены.
  `com.apple.developer.networking.networkextension` — помечен
  `TODO(dev-account)`, ещё не добавлен (Apple выдаёт его только платным
  аккаунтам).
- **Info.plist** — `CFBundleURLTypes` для `flux://`, `LSMultipleInstancesProhibited`.
- **Кросс-платформенный Dart-код**:
  - `lib/app/app_paths.dart` — каталог данных `~/Library/Application Support/flux`.
  - Гейтинг `Platform.isWindows` → `Windows || macOS` в `main.dart`, `tray.dart`,
    `app_title_bar.dart`, `notifications.dart`, `connection_notifications.dart`,
    `connection_screen.dart` (автоконнект на старте, geo-ассеты).
  - `settings_page.dart` — путь к видеофону через `Platform.pathSeparator`
    вместо хардкода `\\`.
  - Иконки трея — `assets/tray_icon*_macos.png` (сконвертированы из `.ico`),
    выбор пути в `tray.dart` по `Platform.isMacOS`.
  - Автозапуск — `lib/app/autostart.dart` (фасад) → `lib/app/macos_autostart.dart`
    (LaunchAgent-plist в `~/Library/LaunchAgents`, без разделения
    standard/elevated — на macOS нет прямого аналога).
- **Диплинки `flux://`** — на macOS через `CFBundleURLTypes` (декларативно) +
  Apple Event `kAEGetURL`, а не argv:
  - `macos/Runner/AppDelegate.swift` — регистрирует обработчик события в
    `applicationWillFinishLaunching`.
  - `macos/Runner/FluxDeepLink.swift` — буфер на случай, если событие пришло
    раньше, чем Flutter engine поднял каналы.
  - `macos/Runner/MainFlutterWindow.swift` — `MethodChannel('flux/deeplink')` +
    `EventChannel('flux/deeplink/stream')`, те же имена, что у Android
    (`MainActivity.kt`) — Dart-сторона (`deep_link.dart`) переиспользует общий
    `nativeInitialDeepLink()`/`nativeDeepLinkStream` для обеих платформ.
- **Proxy-режим** (не требует entitlements/dev-аккаунта, единственный режим,
  который реально можно включить прямо сейчас после первой сборки):
  - `lib/engines/xray/xray_engine_macos.dart` — тот же subprocess-подход, что
    `XrayEngineWindows`.
  - `lib/engines/xray/macos_system_proxy.dart` — системный прокси через
    `networksetup -setwebproxy/-setsecurewebproxy` на все сетевые сервисы
    (аналог реестровой записи на Windows).
  - `lib/engines/xray/child_process_lifecycle_macos.dart` — best-effort замена
    Windows Job Object: убивает дочерние процессы по SIGINT/SIGTERM
    приложения (не защищает от `kill -9` — как и Job Object не защитил бы
    от убийства себя самого).
- **TUN-режим** (структурно есть, реально работать не может без
  Developer-аккаунта на подпись/тестирование — см. "Открытые вопросы"):
  - `lib/engines/singbox/singbox_engine_macos.dart` — обёртка над `sing-box`,
    конфиг переиспользует существующий `buildSingBoxTunBridgeConfig`
    (`singbox_config_mapper.dart` уже платформенно-нейтральный).
  - `lib/engines/singbox/tun_bridge_engine_macos.dart` — связка
    `XrayEngineMacOS` + `SingBoxEngineMacOS`, аналог Windows `TunBridgeEngine`.
  - `lib/engines/xray/macos_elevation.dart` — `osascript ... with
    administrator privileges` для подъёма `sing-box` с root (нужен для
    `utun`) — стопгэп-замена Windows UAC-релонча всего процесса.
- **connection_controller.dart** — явная ветка `Platform.isMacOS`, выбирающая
  `XrayEngineMacOS`/`TunBridgeEngineMacOS`.
- **Скрипты загрузки бинарников** — `scripts/fetch_xray_macos.sh`,
  `scripts/fetch_sing_box_macos.sh` (аналоги `.ps1`, запускать на Маке —
  `uname -m`/`curl`/`unzip`/`tar` недоступны из-под Windows).
- **`.gitignore`** — `assets/xray-macos/*`, `assets/sing-box-macos/*` не
  коммитятся (те же паттерны, что у Windows-вариантов), с `SOURCE.md` в
  каждом каталоге.

### Проверено (насколько возможно с Windows)

- `flutter analyze` — чисто, без предупреждений на новом коде.
- `dart format` — применён только к реально изменённым файлам (случайный
  full-project reformat + апгрейд `pubspec.lock` от `flutter create`
  откачены, чтобы не тащить в PR несвязанные диффы).
- Swift-код (`AppDelegate.swift`, `FluxDeepLink.swift`,
  `MainFlutterWindow.swift`) **не компилировался** — на Windows нет ни
  Xcode, ни `swiftc`. Синтаксис и Flutter macOS API (`FlutterViewController.
  engine.binaryMessenger`, `FlutterMethodChannel`/`FlutterEventChannel`,
  `NSAppleEventManager`) сверены по документации/по аналогии с Android
  (`MainActivity.kt`), но первая реальная компиляция — на Маке.

## Обновление (2026-07-31, реальный Mac, macOS 15.3.1, Xcode 16.4)

Пользователь перешёл на Mac. Поставлены Flutter (brew cask) и CocoaPods
(brew), Xcode 16.4 через App Store (macOS 15.3.1 не поддерживает Xcode 26 —
взята последняя версия под Sequoia, апгрейд ОС не потребовался).

- **Первая сборка** — `flutter build macos --debug` сначала упала:
  `FluxDeepLink.swift` лежал в `macos/Runner/`, но не был добавлен в
  `Runner.xcodeproj/project.pbxproj` (писался вслепую без Xcode, поэтому не
  попал ни в `PBXFileReference`/`PBXBuildFile`, ни в Sources build phase).
  Добавлено вручную в `.pbxproj` — после этого сборка прошла чисто.
- **Copy Files build phase — сделано**: добавлен Run Script build phase
  "Bundle xray + sing-box" в `Runner.xcodeproj/project.pbxproj` (после
  `Bundle Framework`, перед Flutter assemble script), копирует
  `assets/xray-macos/` → `Contents/Resources/xray/` и
  `assets/sing-box-macos/` → `Contents/Resources/sing-box/` через `rsync`
  (no-op с предупреждением, если каталог-источник ещё не заполнен fetch-
  скриптом). TODO-пометки в обоих `SOURCE.md` больше не актуальны.
- **Бинарники загружены и проверены** — `fetch_xray_macos.sh`/
  `fetch_sing_box_macos.sh` отработали, `xray version`/`sing-box version`
  запускаются из собранного бандла по путям, которые ожидают
  `defaultMacosXrayExecutablePath()`/`defaultMacosSingBoxExecutablePath()`.
  Само proxy/TUN-подключение НЕ тестировалось (см. CLAUDE.md — Claude не
  тестирует proxy/TUN в этом проекте ни на одной платформе); это должен
  проверить пользователь лично.
- `flutter analyze` — чисто.
- **Первый реальный запуск приложения** выявил 4 бага, все найдены и
  исправлены:
  - **`about_info.dart` показывал "не найден" для xray-core/sing-box** —
    файл жёстко импортировал и вызывал Windows-функции путей
    (`defaultXrayExecutablePath()`/`defaultSingBoxExecutablePath()`) без
    ветки `Platform.isMacOS`. Добавлено ветвление на
    `defaultMacosXrayExecutablePath()`/`defaultMacosSingBoxExecutablePath()`.
  - **Proxy-подключение мгновенно отваливалось** — настоящая причина
    (нашлась в `~/Library/Application Support/flux/logs/flux_xray_primary.log`):
    `open geosite.dat: no such file or directory`. `geo_assets.dart`
    строил `geoipFilePath()`/`geositeFilePath()` через хардкод `\\`
    вместо `Platform.pathSeparator` — на Windows совпадало с реальным
    разделителем случайно, на macOS файлы скачивались в файл с
    буквальным `\` в имени вместо `geo/geoip.dat`/`geo/geosite.dat`, xray
    не находил geosite-базу для правила `geosite:category-gov-ru` и падал
    сразу после старта. Исправлено, файлы-мусор с `\` в имени удалены.
    После фикса пользователь подтвердил: **Proxy-режим подключается и
    работает**.
  - **Трей-иконка казалась отсутствующей в состоянии "выключено"** — код
    был в порядке (ассеты объявлены, путь верный, `FluxTray.init()` не
    падает — уведомления после неё стартуют штатно). Настоящая причина:
    дефолтная off-иконка (`tray_icon_macos.png`) — блёклый серый контур
    без заливки, при уменьшении до реального размера строки меню (18px)
    становится почти нечитаемой и сливается со светлой темой. Proxy/TUN-
    иконки остались видны, т.к. они цветные и жирные ("PROXY"/"TUN").
    Исправлено — off-иконка теперь рисуется как `isTemplate: true`
    (`tray.dart`), macOS сам красит её под текущую тему меню-бара по
    альфа-каналу; Proxy/TUN-иконки остались цветными (`isTemplate: false`)
    для статус-индикации.
  - **Тайтлбар перекрывал нативные traffic lights** — `TitleBarStyle.hidden`
    (window_manager) на macOS убирает только текст заголовка, сами
    traffic lights (закрыть/свернуть/развернуть) остаются нативными и
    рисуются поверх окна слева. Кастомные кнопки min/max/close на macOS
    были лишними — убраны (оставлены только на Windows), лого сдвинуто в
    центр, слева зарезервирован отступ под traffic lights, высота бара
    уменьшена до 28pt (нативный масштаб) вместо общих 40.

## Обновление (2026-07-31 вечер, реальный Mac): TUN через NetworkExtension

За один вечер тестирования `osascript`-стопгэпа (см. выше, п.4) вскрылись
структурные проблемы (осиротевшие root-процессы, конфликт маршрутов с
другими системными VPN, повторный пароль на каждый disconnect) — решили не
чинить костыль дальше, а сразу написать правильный дизайн:
`NetworkExtension`/`NEPacketTunnelProvider` через System Extension. Как и
весь остальной macOS-порт — написано вслепую (нет платного Developer
аккаунта → System Extension в принципе не подписывается и не активируется
на этой машине), но в этот раз "вслепую" означало не "не проверено вообще",
а "проверено всем, чем можно проверить без подписи": реальная компиляция
и линковка Swift/Go-кода против настоящего `libbox` через
`xcodebuild ... CODE_SIGNING_ALLOWED=NO` — см. ниже, сколько реальных багов
это поймало до того, как код попал к другу.

- **Тулинг** — `gem install xcodeproj` (программное редактирование
  `project.pbxproj` вместо ручной правки текста — для целого нового таргета
  с Info.plist/entitlements/build-фазами хождение по pbxproj руками слишком
  рискованно), Go + `github.com/sagernet/gomobile` (форк, НЕ
  `golang.org/x/mobile` — sing-box использует свой, `v0.1.12`, см.
  `scripts/build_libbox_macos.sh`).
- **`Libbox.xcframework`** — собран `gomobile bind` из
  `SagerNet/sing-box/experimental/libbox` (тот же пакет, которым пользуется
  официальный `SagerNet/sing-box-for-apple`) через
  `go run ./cmd/internal/build_libbox -target apple -platform macos`. Не
  хранится в git (`macos/Frameworks/Libbox.xcframework`, см. её `SOURCE.md`),
  пересобирается `scripts/build_libbox_macos.sh` — не требует dev-аккаунта,
  только Go + Xcode command line tools.
- **`FluxTunnelExtension`** — новый Xcode-таргет (System Extension,
  `com.apple.product-type.system-extension`), добавлен через
  `.build-tools/add_tunnel_extension_target.rb` (`xcodeproj` gem). НЕ
  подключён Copy Files-фазой/зависимостью к `Runner` — иначе обычная
  `flutter build macos` ломалась бы прямо сейчас (таргет не подписывается
  без энтайтлмента); друг подключит вручную (Xcode UI, "Embed System
  Extensions") или доработает тот же скрипт, когда получит аккаунт.
  - `PacketTunnelProvider.swift` — тонкий `NEPacketTunnelProvider`,
    поднимает `libbox` (`LibboxSetup`/`LibboxNewCommandServer`) с тем же
    JSON-конфигом, что строит `buildSingBoxTunBridgeConfig`
    (`singbox_config_mapper.dart`), плюс запускает `xray` обычным дочерним
    процессом (`Process`, без sudo/root — System Extension, в отличие от
    App Extension, не в контейнере приложения и может спавнить процессы;
    xray тут не поднимает TUN сам, ему нужен только исходящий сокет к
    серверу).
  - `FluxPlatformInterface.swift` — реализация `LibboxPlatformInterfaceProtocol`,
    единственный по-настоящему нужный метод — `openTun`: транслирует
    `LibboxTunOptions` (адреса/маршруты/DNS, которые раньше sing-box сам
    настраивал через `auto_route` на голом `utun`) в
    `NEPacketTunnelNetworkSettings` + `setTunnelNetworkSettings` — именно
    поэтому новый TUN не проигрывает по приоритету другим системным VPN
    (см. инцидент с v2RayTun выше). Raw fd для libbox достаётся из
    `packetFlow` через `value(forKeyPath: "socket.fileDescriptor")` — тот
    же приватный KVC-приём, что и у WireGuardKit и подобных.
  - **Реальные баги, пойманные компиляцией/линковкой** (не гадание —
    `xcodebuild` в буквальном смысле on): протоколы libbox называются с
    суффиксом `Protocol` (`LibboxPlatformInterfaceProtocol`, не
    `LibboxPlatformInterface` — то имя занято Go-backed классом), несколько
    методов переименованы относительно заголовка (`autoDetectControl`
    вместо `autoDetectInterfaceControl`, `send` вместо `sendNotification`),
    throws-метод не может одновременно возвращать Optional (throws сам
    выражает "нет значения"), свободные C-функции (`LibboxSetup`,
    `LibboxNewCommandServer`) не получают автоматический throws-бриджинг
    (в отличие от методов), линковке не хватало `SystemConfiguration.framework`
    и `-lresolv` (Go-рантайм/Chromium-код внутри libbox), System Extension
    (в отличие от App Extension) требует собственной точки входа —
    добавлен `main.swift` с `NEProvider.startSystemExtensionMode()`, CocoaPods
    прописывает `-framework local_notifier` в общий для всех таргетов
    `OTHER_LDFLAGS` — пришлось явно переопределить для нового таргета.
- **`NetworkExtensionBridge.swift`** (`macos/Runner/`) — активация System
  Extension (`OSSystemExtensionRequest`) + `NETunnelProviderManager` +
  `flux/vpn` MethodChannel/`flux/vpn/status` EventChannel — те же имена
  каналов, что на Android (`MainActivity.kt`/`VpnStatusBridge.kt`,
  `xray_engine_android.dart`), тот же паттерн (оптимистичный `connected`
  сразу после старта, асинхронные `stopped`/`error` через EventChannel).
  Реально компилируется в составе обычной `flutter build macos`.
- **`TunBridgeEngineMacOSNe`** (`lib/engines/singbox/tun_bridge_engine_macos_ne.dart`)
  — новая Dart-реализация `CoreEngine`, подключена в `connection_controller.dart`
  вместо `TunBridgeEngineMacOS` для `ConnectionMode.tun` на macOS. Старый
  `osascript`-стопгэп (`TunBridgeEngineMacOS`/`SingBoxEngineMacOS`/
  `macos_elevation.dart`) **не удалён** — рабочий, сегодня же продебажен на
  реальном Маке, оставлен как референс/fallback, просто больше не
  используется по умолчанию.
- **Чего не хватает / не проверено**: буквально всё в рантайме — активация
  расширения, `openTun` при реальном коннекте, поведение `xray`-подпроцесса
  внутри System Extension, XPC/sandbox-нюансы, которые могут вскрыться
  только при реальной активации с подписью. Это первая точка, которую
  нужно тестировать другу, когда появится dev-аккаунт (см. "Открытые
  вопросы" ниже).

## Что осталось до паритета с Windows

Порядок — примерно в порядке "что нужно раньше".

1. ~~Первая сборка в Xcode~~ — готово, см. обновление выше.
2. ~~Xcode Copy Files build phase~~ — готово, см. обновление выше.
3. ~~Proxy-режим — первый реальный сквозной тест~~ — готово, пользователь
   подтвердил: подключается и работает (после фикса geo-путей, см.
   обновление выше).
4. **TUN-режим** — по умолчанию теперь `TunBridgeEngineMacOSNe`
   (`NetworkExtension`/System Extension, см. обновление выше) — реальная
   проверка активации/подключения возможна только у друга с dev-аккаунтом.
   Ниже — история с осознанно оставленным старым `osascript`-стопгэпом
   (`TunBridgeEngineMacOS`), актуальна, если решат откатиться на него:
   - **Найден и исправлен баг до первого теста**: `startElevatedMacos`
     (`macos_elevation.dart`) склеивал `executable`/аргументы через голый
     пробел без кавычек — путь к sing-box-конфигу лежит в
     `~/Library/Application Support/flux/...`, пробел в "Application
     Support" разбивал команду на два shell-аргумента, `do shell script`
     падал с "no such file or directory" на конфиге сразу после запуска.
     Тот же класс бага, что уже сломал Proxy-режим (`geo_assets.dart`, см.
     обновление выше) — только этот пойман до реального теста, а не после.
     Исправлено — каждый токен теперь в одинарных кавычках.
   - Осталось проверить вживую: диалог пароля показывается, `sing-box`
     реально поднимает `utun` с `auto_route`, трафик идёт через тоннель.
   - Отдельно проверить обрыв/`stop()` — см. предупреждение в
     `macos_elevation.dart` про то, что `process.kill()` на `osascript` не
     гарантированно убивает реальный `sing-box`-процесс (это может остаться
     зависшим TUN-адаптером/процессом после "Отключить"). Не исправлено
     заранее умышленно: `sing-box` поднят от root, обычный `pkill` из
     приложения (не-root) его не убьёт — нужна ещё одна elevated-команда,
     то есть ещё один пароль-промпт при каждом disconnect. Решение зависит
     от того, воспроизводится ли реально осиротевший процесс — проверяет
     пользователь.
5. ~~App-иконка~~ — готово. `flutter_launcher_icons` 0.14.4 поддерживает
   `macos:` секцию — добавлена в `pubspec.yaml`, генерирует
   `Assets.xcassets/AppIcon.appiconset/*.png` из отдельного source-файла
   `docs/media/icon_with_black.png` (не `assets/icon.png` — тот прозрачный
   контур-логотип без фона, Apple ожидает непрозрачную заливку до краёв
   иконки; `icon_with_black.png` уже с фоном/скруглением). Побочный эффект
   пакета: каждый прогон `dart run flutter_launcher_icons` заодно
   переписывает `android/.../AndroidManifest.xml` (иконку quick-settings
   tile `FluxQuickTile` на `@mipmap/ic_launcher`) — приходится откатывать
   этот файл вручную после каждого запуска. Дока в Dock/LaunchServices
   аггрессивно кеширует иконку по пути бандла — после пересборки помогает
   `lsregister -f <path>` + `touch <path>` + `killall Dock`.
6. **Автозапуск** — `macos_autostart.dart` (LaunchAgent-plist) написан, но
   ни разу не выполнялся: проверить, что `launchctl` реально подхватывает
   plist без явного `launchctl load` (сейчас код полагается на то, что
   LaunchAgents подхватываются автоматически при следующем логине — если
   нет, добавить явный `launchctl bootstrap`/`load` вызов).
7. **Автозапуск с системным прокси/TUN "из коробки"** — на Windows автозапуск
   умеет сразу переподключаться (см. `connection_screen.dart`,
   `_autoConnectOnStartup`) — на macOS эта ветка уже включена
   (`Platform.isWindows || Platform.isMacOS`), но не проверена вместе с
   LaunchAgent-стартом (окно должно оставаться скрытым, см. `--minimized`).
8. **Тайтлбар/трей — визуальная доводка**: кастомный тайтлбар с
   Windows-style кнопками свернуть/развернуть/закрыть сейчас просто
   переиспользуется на macOS as-is (см. `app_title_bar.dart`) — не
   идиоматично для macOS (нет traffic lights слева), но осознанно оставлено
   как временное решение, чтобы не блокировать функциональность визуальной
   полировкой. Дизайн-доводка — отдельная задача после того, как
   proxy/TUN заработают.
9. **Автообновление/установщик** — на Windows есть `build_installer.ps1`
   (Inno Setup) и `.github/workflows/release.yml`'s `build-windows` job;
   для macOS нет ни installer/DMG-скрипта, ни CI job. Осмысленно делать
   только после того, как появится сертификат подписи/нотаризации (см.
   "Открытые вопросы" ниже) — неподписанный `.app` всё равно потребует
   Gatekeeper-обхода при каждой раздаче.

## Открытые вопросы / зависит от Developer-аккаунта друга

- **`NetworkExtension`/`NEPacketTunnelProvider`** — уже написан
  (`FluxTunnelExtension`, `TunBridgeEngineMacOSNe`, см. обновление выше по
  дате), реально компилируется и линкуется, но не подписан и не активирован
  — требует платного Apple Developer аккаунта для энтайтлмента
  `com.apple.developer.networking.networkextension`. Первая реальная
  проверка (активация расширения, реальный `openTun`, поведение
  `xray`-подпроцесса внутри System Extension) — у друга, когда появится
  аккаунт. `TunBridgeEngineMacOS`/`osascript`-элевация оставлена в коде как
  рабочий fallback, но больше не используется по умолчанию.
- **Подпись и нотаризация** — без Developer ID Application-сертификата
  собранный `.app` будет блокироваться Gatekeeper при скачивании
  (`"Flux" is damaged and can't be opened` или похожее) — раздать друзьям
  для тестирования можно будет только через `xattr -d com.apple.quarantine`
  или явный обход в System Settings, пока не появится сертификат у друга.
- **Хелпер-процесс вместо `osascript`** — если TUN-режим на голом
  subprocess+sudo окажется неудобным/ненадёжным (см. предупреждение в
  `macos_elevation.dart`), следующий шаг — подписанный privileged helper
  tool (`SMJobBless` или новый `SMAppService`, macOS 13+) — тоже требует
  подписи, то есть friend's аккаунта.
- **Минимальная версия macOS** — `MACOSX_DEPLOYMENT_TARGET` сейчас `10.15`
  (дефолт от `flutter create`), не проверялось, действительно ли всё
  используемое (sing-box `utun`+`auto_route`, `SMAppService` если до него
  дойдёт) работает на настолько старой версии — возможно, стоит поднять
  до 12/13 после первых тестов на реальном железе.

## Что делать дальше (по порядку)

1. Перенести/запушить ветку на Мак (или клонировать репозиторий там),
   поставить Flutter + Xcode.
2. Открыть `macos/Runner.xcworkspace`, прогнать `flutter pub get`, собрать
   `flutter run -d macos` — почти наверняка что-то не скомпилируется с
   первого раза (Swift-файлы никогда не проверялись компилятором), чинить
   по одной ошибке.
3. Настроить Copy Files build phase для `xray`/`sing-box` (п.2 выше).
4. Прогнать `fetch_xray_macos.sh`, проверить Proxy-режим целиком (подключение,
   `networksetup`, реальный интернет через тоннель, отключение возвращает
   прокси в исходное состояние).
5. Прогнать `fetch_sing_box_macos.sh`, проверить TUN-режим, обязательно
   проверить `stop()`/переключение сервера (осиротевший `sing-box`-процесс —
   главный подозреваемый при багах "не могу переподключиться").
6. Проверить диплинки (`flux://...` из браузера/терминала — оба варианта:
   холодный старт и уже запущенное приложение) и автозапуск.
7. Как только у друга появится Developer-аккаунт — вернуться к пункту
   "Открытые вопросы" и заменить `osascript`-элевацию на `NetworkExtension`,
   добавить недостающий entitlement, настроить подпись/нотаризацию и только
   тогда думать про установщик/автообновление и релиз в CI.
