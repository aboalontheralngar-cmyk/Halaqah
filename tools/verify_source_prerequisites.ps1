[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location

try {
    Set-Location $projectRoot

    $missingFonts = @(
        'assets/fonts/Tajawal-400.ttf',
        'assets/fonts/Tajawal-700.ttf'
    ) | Where-Object { -not (Test-Path -LiteralPath $_) }

    if ($missingFonts.Count -gt 0) {
        $joined = $missingFonts -join ', '
        throw "Required Tajawal font binaries are missing: $joined. This source-upgrade package intentionally does not redistribute font binaries. Apply the modified-files package over the existing project or restore the existing font files first."
    }

    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter was not found in PATH.'
    }

    if (-not (Test-Path -LiteralPath 'pubspec.lock')) {
        Write-Host 'pubspec.lock is missing; generating it from the pinned direct dependencies...' -ForegroundColor Yellow
        & flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "flutter pub get failed with exit code $LASTEXITCODE"
        }
    }

    if (-not (Test-Path -LiteralPath 'pubspec.lock')) {
        throw 'pubspec.lock was not generated. Stop before building a release.'
    }

    Write-Host 'Flutter source prerequisites passed.' -ForegroundColor Green
}
finally {
    Set-Location $previousLocation
}
