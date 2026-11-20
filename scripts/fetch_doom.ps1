#Requires -Version 5
$ErrorActionPreference = 'Stop'
$doomRoot = Split-Path -Parent $PSScriptRoot
$doomDownloads = Join-Path $doomRoot 'build\doom-downloads'
$doomDestination = Join-Path $doomRoot 'assets\doom'
New-Item -ItemType Directory -Path $doomDownloads,$doomDestination -Force | Out-Null
"DOOM asset scan — $([DateTime]::UtcNow.ToString('o'))" |
    Set-Content -LiteralPath (Join-Path $doomDownloads 'defender-scan.txt') -Encoding utf8

$doomEngineUrl = 'https://github.com/fabiangreffrath/crispy-doom/releases/download/crispy-doom-7.2/crispy-doom-7.2.0-win64.zip'
$doomDataUrl = 'https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip'
$doomSourceUrl = 'https://github.com/fabiangreffrath/crispy-doom/archive/refs/tags/crispy-doom-7.2.zip'
foreach ($doomDownload in @(
    @{ Url=$doomEngineUrl; Name='crispy-doom-7.2.0-win64.zip' },
    @{ Url=$doomDataUrl; Name='freedoom-0.13.0.zip' },
    @{ Url=$doomSourceUrl; Name='crispy-doom-7.2-source.zip' }
)) {
    $doomArchive = Join-Path $doomDownloads $doomDownload.Name
    if (-not (Test-Path -LiteralPath $doomArchive)) {
        Invoke-WebRequest -Uri $doomDownload.Url -OutFile "$doomArchive.part"
        Move-Item -LiteralPath "$doomArchive.part" -Destination $doomArchive
    }
}

function Invoke-DoomScan([string]$Target) {
    $doomScanner = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path -LiteralPath $doomScanner)) { throw 'Microsoft Defender scanner not found; files have not been approved for packaging.' }
    & $doomScanner -Scan -ScanType 3 -File $Target -DisableRemediation 2>&1 |
        Tee-Object -FilePath (Join-Path $doomDownloads 'defender-scan.txt') -Append
    if ($LASTEXITCODE -ne 0) { throw "Defender scan failed or found a threat (exit $LASTEXITCODE): $Target" }
}
Invoke-DoomScan $doomDownloads

$doomEngineExtract = Join-Path $doomDownloads 'engine'
$doomDataExtract = Join-Path $doomDownloads 'data'
Expand-Archive -LiteralPath (Join-Path $doomDownloads 'crispy-doom-7.2.0-win64.zip') -DestinationPath $doomEngineExtract -Force
Expand-Archive -LiteralPath (Join-Path $doomDownloads 'freedoom-0.13.0.zip') -DestinationPath $doomDataExtract -Force
Copy-Item -Path (Join-Path $doomEngineExtract '*') -Destination $doomDestination -Recurse -Force
$doomWad = Get-ChildItem -LiteralPath $doomDataExtract -Filter freedoom1.wad -Recurse | Select-Object -First 1
if (-not $doomWad) { throw 'freedoom1.wad not found in official archive' }
Copy-Item -LiteralPath $doomWad.FullName -Destination (Join-Path $doomDestination 'freedoom1.wad') -Force
$doomLicense = Get-ChildItem -LiteralPath $doomDataExtract -Filter COPYING* -Recurse | Select-Object -First 1
if (-not $doomLicense) { throw 'Freedoom license not found' }
Copy-Item -LiteralPath $doomLicense.FullName -Destination (Join-Path $doomDestination 'FREEDOOM-COPYING.txt') -Force
Copy-Item -LiteralPath (Join-Path $doomDownloads 'crispy-doom-7.2-source.zip') -Destination $doomDestination -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$doomSourceZip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $doomDownloads 'crispy-doom-7.2-source.zip'))
try {
    $doomCopyingEntry = $doomSourceZip.Entries | Where-Object { $_.FullName -match '/COPYING(\.md)?$' } | Select-Object -First 1
    if (-not $doomCopyingEntry) { throw 'Engine license missing from source archive' }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($doomCopyingEntry, (Join-Path $doomDestination 'CRISPY-COPYING.txt'), $true)
} finally { $doomSourceZip.Dispose() }
if (-not (Test-Path -LiteralPath (Join-Path $doomDestination 'crispy-doom.exe'))) { throw 'crispy-doom.exe not found in official archive' }
Invoke-DoomScan $doomDestination

Get-ChildItem -LiteralPath $doomDestination -File -Recurse | Get-FileHash -Algorithm SHA256 |
    Select-Object @{Name='File';Expression={$_.Path.Substring($doomDestination.Length+1)}},Hash |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $doomDownloads 'sha256.json') -Encoding utf8
Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $doomDownloads 'defender-status.json') -Encoding utf8
Write-Output "DOOM runtime ready: $doomDestination"
