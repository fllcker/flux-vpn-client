# sing-box binary

Этот каталог заполняется скриптом `scripts/fetch_sing_box.ps1` — сам
бинарник не хранится в git (см. `.gitignore`).

Запуск:

```powershell
./scripts/fetch_sing_box.ps1
```

Скрипт скачивает последний stable-релиз `sing-box-*-windows-amd64.zip` с
[SagerNet/sing-box](https://github.com/SagerNet/sing-box/releases). В
отличие от Xray, отдельный `wintun.dll` рядом не нужен — sing-box сам
извлекает драйвер во время работы (проверено эмпирически: без единого
`wintun.dll` поблизости процесс всё равно доходит до `configure tun
interface: Access is denied` — это ошибка нехватки прав, а не отсутствующей
DLL).

Используется только как TUN-режим — packet-capture мост перед уже
работающим SOCKS-инбаундом xray, см. `lib/engines/singbox/`.
