# xray-core binary (macOS)

Этот каталог заполняется скриптом `scripts/fetch_xray_macos.sh` — сам
бинарник не хранится в git (см. `.gitignore`). Аналог `assets/xray/`
(Windows), см. его `SOURCE.md` для общего контекста про `geoip.dat`/
`geosite.dat`.

Запуск (на самом Mac — скрипт использует `uname -m`, `curl`, `unzip`):

```bash
./scripts/fetch_xray_macos.sh
```

TODO: в отличие от Windows (`windows/CMakeLists.txt` копирует `assets/xray`
рядом с `flux.exe` при каждой сборке), для macOS ещё не настроена аналогичная
Xcode "Copy Files" build phase, кладущая этот каталог в
`Flux.app/Contents/Resources/xray/` (путь, который ожидает
`defaultMacosXrayExecutablePath()` в `lib/engines/xray/xray_engine_macos.dart`)
— сделать это в Xcode на реальном Mac, здесь только сам fetch-скрипт.
