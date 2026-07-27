# xray-core binary

Этот каталог заполняется скриптом `scripts/fetch_xray.ps1` — сам бинарник не
хранится в git (см. `.gitignore`).

Запуск:

```powershell
./scripts/fetch_xray.ps1
```

Скрипт скачивает последний stable-релиз `Xray-windows-64.zip` с
[XTLS/Xray-core](https://github.com/XTLS/Xray-core/releases) и
распаковывает его сюда (`xray.exe`, ...).

`geoip.dat`/`geosite.dat` из этого архива скрипт сразу удаляет — они больше
не часть сборки (ROADMAP.md, трек 20). Вместо них приложение само качает эти
файлы в рантайме в `%AppData%\flux\geo` (`lib/engines/geo_assets.dart`),
независимо от релизов приложения; путь к ним передаётся xray-core через
`XRAY_LOCATION_ASSET`.
