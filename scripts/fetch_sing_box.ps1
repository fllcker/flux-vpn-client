#Requires -Version 5
<#
Downloads the latest stable sing-box Windows release into assets/sing-box/.
Unlike Xray, sing-box's own binary embeds wintun (confirmed empirically:
running sing-box.exe with no wintun.dll anywhere nearby still reaches
"configure tun interface: Access is denied" — a privilege error, not a
missing-DLL error — so it extracts the driver itself at runtime), so no
separate wintun.dll fetch is needed here. See assets/sing-box/SOURCE.md.
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$destDir = Join-Path $repoRoot "assets\sing-box"
$zipPath = Join-Path $env:TEMP "sing-box-windows-amd64.zip"

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/SagerNet/sing-box/releases/latest"
$asset = $release.assets | Where-Object {
    $_.name -like "sing-box-*-windows-amd64.zip" -and $_.name -notlike "*legacy-windows-7*"
}
if (-not $asset) {
    throw "sing-box-*-windows-amd64.zip not found in latest release $($release.tag_name)"
}

Write-Output "Downloading sing-box $($release.tag_name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

New-Item -ItemType Directory -Path $destDir -Force | Out-Null

# sing-box's zip extracts into a version-named subfolder (unlike Xray's flat
# zip) — expand to a temp dir and move just the files we need up one level.
$sbExtractDir = Join-Path $env:TEMP "sing-box-extract"
if (Test-Path $sbExtractDir) { Remove-Item $sbExtractDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $sbExtractDir -Force
$innerDir = Get-ChildItem $sbExtractDir -Directory | Select-Object -First 1
Copy-Item (Join-Path $innerDir.FullName "sing-box.exe") $destDir -Force
Copy-Item (Join-Path $innerDir.FullName "LICENSE") (Join-Path $destDir "LICENSE") -Force
Remove-Item $zipPath, $sbExtractDir -Recurse -Force

Write-Output "sing-box $($release.tag_name) extracted to $destDir"
