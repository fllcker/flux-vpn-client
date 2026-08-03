# Libbox.xcframework

Собирается скриптом `scripts/build_libbox_macos.sh` из исходников
`SagerNet/sing-box` через `gomobile bind` — сам xcframework не хранится в
git (см. `.gitignore`), как и `assets/xray-macos`/`assets/sing-box-macos`.

Запуск (на самом Mac — нужны Go + Xcode command line tools; НЕ требует
платного Apple Developer-аккаунта, тот нужен только для подписи самого
`FluxTunnelExtension`-таргета):

```bash
./scripts/build_libbox_macos.sh
```
