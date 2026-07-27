#Requires -Version 5
<#
Downloads the latest stable Xray-core Windows release into assets/xray/.
See assets/xray/SOURCE.md.
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$destDir = Join-Path $repoRoot "assets\xray"
$zipPath = Join-Path $env:TEMP "Xray-windows-64.zip"

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/XTLS/Xray-core/releases/latest"
$asset = $release.assets | Where-Object { $_.name -eq "Xray-windows-64.zip" }
if (-not $asset) {
    throw "Xray-windows-64.zip not found in latest release $($release.tag_name)"
}

Write-Output "Downloading Xray-core $($release.tag_name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

New-Item -ItemType Directory -Path $destDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
Remove-Item $zipPath

# geoip.dat/geosite.dat больше не часть сборки (ROADMAP.md, трек 20) — они
# качаются в рантайме приложением (lib/engines/geo_assets.dat) в
# %AppData%\flux\geo, чтобы обновляться независимо от релизов и без
# необходимости пересобирать/переустанавливать Flux. Xray-windows-64.zip всё
# равно их содержит (это апстримный набор от Loyalsoldier/v2ray-rules-dat),
# так что просто удаляем — они бы не использовались (xray запускается с
# XRAY_LOCATION_ASSET, указывающим на рантайм-каталог).
foreach ($name in @("geoip.dat", "geosite.dat")) {
    $path = Join-Path $destDir $name
    if (Test-Path $path) {
        Remove-Item $path
    }
}

Write-Output "Xray-core $($release.tag_name) extracted to $destDir"
