# xray-core binary

Этот каталог заполняется скриптом `scripts/fetch_xray.ps1` — сам бинарник
и geoip/geosite базы не хранятся в git (см. `.gitignore`).

Запуск:

```powershell
./scripts/fetch_xray.ps1
```

Скрипт скачивает последний stable-релиз `Xray-windows-64.zip` с
[XTLS/Xray-core](https://github.com/XTLS/Xray-core/releases) и
распаковывает его сюда (`xray.exe`, `geoip.dat`, `geosite.dat`, ...).
