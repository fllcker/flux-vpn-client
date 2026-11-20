#Requires -Version 5
<#
Builds libv2ray.aar (xray-core for Android, via gomobile bind against
2dust/AndroidLibXrayLite) and drops it into android/app/libs/.
See android/app/libs/SOURCE.md.

Requires: Go, Android SDK + NDK. The script installs the gomobile tools
at the version used by AndroidLibXrayLite. Unlike scripts/fetch_xray.ps1 it doesn't
download a prebuilt binary — there is no official prebuilt AAR, so this
actually compiles xray-core via Go Mobile. Expect this to take a while and
to need several GB of free disk for Go's build/module caches (set GOCACHE/
GOMODCACHE/GOTMPDIR to a drive with room if the default (under
%LOCALAPPDATA%) is tight).
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$versions = ConvertFrom-StringData (Get-Content -Raw (Join-Path $PSScriptRoot "core_versions.env"))
$ref = $versions.ANDROID_XRAY_REF
$mobile = $versions.ANDROID_GOMOBILE_VERSION
$cloneDir = Join-Path $repoRoot ".build-tools\android-xray-lite\$ref"
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

if (-not (Test-Path (Join-Path $cloneDir "go.mod"))) {
    New-Item -ItemType Directory -Path $cloneDir -Force | Out-Null
    $archive = Join-Path $cloneDir "source.tar.gz"
    Invoke-WebRequest -Uri "https://codeload.github.com/2dust/AndroidLibXrayLite/tar.gz/$ref" -OutFile $archive
    tar.exe -xzf $archive -C $cloneDir --strip-components 1
    if ($LASTEXITCODE -ne 0) { throw "Could not extract AndroidLibXrayLite $ref" }
    Remove-Item -LiteralPath $archive
}

$previousGoBin = $env:GOBIN
$previousPath = $env:Path
Push-Location $cloneDir
try {
    $env:GOBIN = Join-Path $cloneDir "bin"
    $env:Path = "$env:GOBIN;$env:Path"
    go install "golang.org/x/mobile/cmd/gomobile@$mobile" "golang.org/x/mobile/cmd/gobind@$mobile"
    if ($LASTEXITCODE -ne 0) { throw "Could not install gomobile $mobile" }
    go mod tidy -v
    if ($LASTEXITCODE -ne 0) { throw "go mod tidy failed" }
    gomobile bind -v -target=android/arm64 -androidapi 24 -trimpath `
        -ldflags='-s -w -buildid= -checklinkname=0' -o libv2ray.aar ./
    if ($LASTEXITCODE -ne 0) { throw "gomobile bind failed" }
} finally {
    $env:GOBIN = $previousGoBin
    $env:Path = $previousPath
    Pop-Location
}

New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
Copy-Item (Join-Path $cloneDir "libv2ray.aar") (Join-Path $libsDir "libv2ray.aar") -Force

Write-Output "libv2ray.aar built and copied to $libsDir"
