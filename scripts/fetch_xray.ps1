#Requires -Version 5
<#
Downloads the pinned Xray-core Windows release into assets/xray/.
See assets/xray/SOURCE.md.
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$destDir = Join-Path $repoRoot "assets\xray"
$zipPath = Join-Path $env:TEMP "Xray-windows-64.zip"

$versions = ConvertFrom-StringData (Get-Content -Raw (Join-Path $PSScriptRoot "core_versions.env"))
$version = $versions.XRAY_VERSION

Write-Output "Downloading Xray-core $version..."
Invoke-WebRequest -Uri "https://github.com/XTLS/Xray-core/releases/download/$version/Xray-windows-64.zip" -OutFile $zipPath

New-Item -ItemType Directory -Path $destDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
Remove-Item $zipPath

# geoip.dat/geosite.dat больше не часть сборки (ROADMAP.md, трек 20) — они
# качаются в рантайме приложением (lib/engines/geo_assets.dart) в
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

Write-Output "Xray-core $version extracted to $destDir"
