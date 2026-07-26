# libv2ray.aar — xray-core for Android

Этот каталог заполняется скриптом `scripts/build_android_xray.ps1` — сам
`.aar` не хранится в git (см. `.gitignore`), как и клон исходников в
`tool/android-xray-lite/src/`.

Запуск:

```powershell
./scripts/build_android_xray.ps1
```

В отличие от `scripts/fetch_xray.ps1`/`fetch_sing_box.ps1` (скачивают
готовый релизный бинарник), здесь **компилируется** xray-core через
`gomobile bind` — официального прекомпилированного AAR под Android у
XTLS/Xray-core нет. Сборка идёт через
[2dust/AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) —
тот же путь, которым собирает xray-core под Android v2rayNG (самый
популярный Android-клиент на этом ядре). Нужны Go + `gomobile`/`gobind`
(`go install golang.org/x/mobile/cmd/gomobile@latest`) и Android
SDK/NDK. Сборка долгая и требует нескольких GB свободного места под
Go-кеши (`GOCACHE`/`GOMODCACHE`/`GOTMPDIR`) — если диск с `%LOCALAPPDATA%`
забит, перенаправь их (`go env -w GOCACHE=... GOMODCACHE=... GOTMPDIR=...`)
на диск, где есть место.

Собирается только под `android/arm64` (`-target=android/arm64
-androidapi 24`) — под реальные устройства, без эмулятора x86/x86_64,
пока не появится причина его поддерживать.
