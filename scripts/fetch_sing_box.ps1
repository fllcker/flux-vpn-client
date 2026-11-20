#Requires -Version 5
<#
Downloads the pinned sing-box Windows release into assets/sing-box/.
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

$versions = ConvertFrom-StringData (Get-Content -Raw (Join-Path $PSScriptRoot "core_versions.env"))
$version = $versions.SING_BOX_VERSION
$asset = "sing-box-$($version.TrimStart('v'))-windows-amd64.zip"

Write-Output "Downloading sing-box $version..."
Invoke-WebRequest -Uri "https://github.com/SagerNet/sing-box/releases/download/$version/$asset" -OutFile $zipPath

New-Item -ItemType Directory -Path $destDir -Force | Out-Null

# sing-box's zip extracts into a version-named subfolder (unlike Xray's flat
# zip) — expand to a temp dir and move just the files we need up one level.
$sbExtractDir = Join-Path ([IO.Path]::GetFullPath($env:TEMP)) ("sing-box-extract-" + [guid]::NewGuid())
Expand-Archive -Path $zipPath -DestinationPath $sbExtractDir -Force
$innerDir = Get-ChildItem $sbExtractDir -Directory | Select-Object -First 1
Copy-Item (Join-Path $innerDir.FullName "sing-box.exe") $destDir -Force
Copy-Item (Join-Path $innerDir.FullName "LICENSE") (Join-Path $destDir "LICENSE") -Force
Remove-Item -LiteralPath $zipPath -Force
Remove-Item -LiteralPath $sbExtractDir -Recurse -Force

Write-Output "sing-box $version extracted to $destDir"
