#Requires -Version 5
<#
Builds libv2ray.aar (xray-core for Android, via gomobile bind against
2dust/AndroidLibXrayLite) and drops it into android/app/libs/.
See android/app/libs/SOURCE.md.

Requires: Go, `go install golang.org/x/mobile/cmd/gomobile@latest` (and
gobind), Android SDK + NDK. Unlike scripts/fetch_xray.ps1 this doesn't
download a prebuilt binary — there is no official prebuilt AAR, so this
actually compiles xray-core via Go Mobile. Expect this to take a while and
to need several GB of free disk for Go's build/module caches (set GOCACHE/
GOMODCACHE/GOTMPDIR to a drive with room if the default (under
%LOCALAPPDATA%) is tight).
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$cloneDir = Join-Path $repoRoot "tool\android-xray-lite\src"
$libsDir = Join-Path $repoRoot "android\app\libs"

if (-not $env:ANDROID_HOME) {
    throw "ANDROID_HOME is not set — point it at your Android SDK."
}
$ndkRoot = Join-Path $env:ANDROID_HOME "ndk"
if (-not $env:ANDROID_NDK_HOME) {
    $latestNdk = Get-ChildItem $ndkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latestNdk) {
        throw "No NDK found under $ndkRoot and ANDROID_NDK_HOME is not set."
    }
    $env:ANDROID_NDK_HOME = $latestNdk.FullName
}
Write-Output "Using ANDROID_NDK_HOME=$($env:ANDROID_NDK_HOME)"

if (-not (Test-Path $cloneDir)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $cloneDir) -Force | Out-Null
    git clone --depth 1 https://github.com/2dust/AndroidLibXrayLite.git $cloneDir
} else {
    Write-Output "Reusing existing clone at $cloneDir (delete it for a fresh checkout)."
}

Push-Location $cloneDir
try {
    go mod tidy -v
    gomobile bind -v -target=android/arm64 -androidapi 24 -trimpath `
        -ldflags='-s -w -buildid= -checklinkname=0' -o libv2ray.aar ./
} finally {
    Pop-Location
}

New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
Copy-Item (Join-Path $cloneDir "libv2ray.aar") (Join-Path $libsDir "libv2ray.aar") -Force

Write-Output "libv2ray.aar built and copied to $libsDir"
