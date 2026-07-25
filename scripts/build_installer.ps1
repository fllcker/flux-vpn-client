#Requires -Version 5
<#
Builds the Release exe and packages it into a single FluxSetup-<version>.exe
installer with Inno Setup — replaces manually zipping up
build\windows\x64\runner\Release\ for distribution (see ROADMAP.md, трек 13).

Requires Inno Setup 6 (iscc.exe) installed — https://jrsoftware.org/isinfo.php.
Not run as part of `flutter build`/CI; invoke by hand when cutting a release.
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$pubspec = Get-Content (Join-Path $repoRoot "pubspec.yaml") -Raw
if ($pubspec -notmatch "(?m)^version:\s*(\S+)") {
    throw "Could not find 'version:' in pubspec.yaml"
}
# pubspec version is "1.0.0+1" (semver+build number) — Inno Setup's
# AppVersion only wants the semver part.
$version = $Matches[1].Split('+')[0]

Write-Output "Building Flux $version (Release)..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows --release failed" }

$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $candidate = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    if (Test-Path $candidate) {
        $iscc = Get-Item $candidate
    } else {
        throw "iscc.exe not found — install Inno Setup 6 (https://jrsoftware.org/isinfo.php) or add it to PATH"
    }
}

Write-Output "Packaging installer with Inno Setup..."
& $iscc.Path "/DAppVersion=$version" (Join-Path $repoRoot "windows\installer\flux.iss")
if ($LASTEXITCODE -ne 0) { throw "iscc failed" }

Write-Output "Done: build\installer\FluxSetup-$version.exe"
