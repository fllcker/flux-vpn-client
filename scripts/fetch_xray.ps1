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

Write-Output "Xray-core $($release.tag_name) extracted to $destDir"
