# sing-box binary (macOS)

Этот каталог заполняется скриптом `scripts/fetch_sing_box_macos.sh` — сам
бинарник не хранится в git (см. `.gitignore`). Аналог `assets/sing-box/`
(Windows), см. его `SOURCE.md`.

Запуск (на самом Mac):

```bash
./scripts/fetch_sing_box_macos.sh
```

TODO: та же незакрытая Xcode "Copy Files" build phase, что и в
`assets/xray-macos/SOURCE.md` — этот каталог должен попасть в
`Flux.app/Contents/Resources/sing-box/`, путь, который ожидает
`defaultMacosSingBoxExecutablePath()` в
`lib/engines/singbox/singbox_engine_macos.dart`.
