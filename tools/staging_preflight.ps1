[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipWeb,
    [switch]$SkipApk
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

try {
    Set-Location $projectRoot

    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter was not found in PATH.'
    }
    if (-not $SkipWeb -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'npm was not found in PATH. Use -SkipWeb only for an urgent Android-only check.'
    }

    $versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$'
    if ($null -eq $versionLine) {
        throw 'The Flutter version is missing from pubspec.yaml.'
    }
    $version = $versionLine.Matches[0].Groups[1].Value.Trim()
    Write-Host "Halaqah RC2 staging preflight — version $version" -ForegroundColor Green

    if ($Clean) {
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('clean') -Label 'Flutter clean'
    }

    Invoke-CheckedCommand -Command 'flutter' -Arguments @('pub', 'get') -Label 'Flutter dependencies'
    Invoke-CheckedCommand -Command 'flutter' -Arguments @('analyze') -Label 'Flutter analyze'
    Invoke-CheckedCommand -Command 'flutter' -Arguments @('test') -Label 'Flutter tests'

    if (-not $SkipApk) {
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('build', 'apk', '--release') -Label 'Staging release APK'
        $apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
        if (-not (Test-Path $apkPath)) {
            throw "APK was not created at $apkPath"
        }
        $artifactDirectory = Join-Path $projectRoot 'build\release-artifacts'
        New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
        $safeVersion = $version -replace '[^A-Za-z0-9._-]', '-'
        $artifactPath = Join-Path $artifactDirectory "halaqah-rc2-$safeVersion.apk"
        Copy-Item -LiteralPath $apkPath -Destination $artifactPath -Force

        $apkHash = Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
        $checksumPath = "$artifactPath.sha256"
        $checksumLine = "$($apkHash.Hash.ToLowerInvariant())  $(Split-Path -Leaf $artifactPath)"
        Set-Content -LiteralPath $checksumPath -Value $checksumLine -Encoding ascii

        Write-Host "`nAPK: $artifactPath" -ForegroundColor Green
        Write-Host "SHA-256 file: $checksumPath" -ForegroundColor Green
        Write-Host "SHA-256: $($apkHash.Hash)" -ForegroundColor Green
    }

    if (-not $SkipWeb) {
        Push-Location (Join-Path $projectRoot 'website')
        try {
            Invoke-CheckedCommand -Command 'npm' -Arguments @('ci') -Label 'Locked web dependencies'
            Invoke-CheckedCommand -Command 'npm' -Arguments @('run', 'quality:ci') -Label 'Web quality gates'
        }
        finally {
            Pop-Location
        }
    }

    Write-Host "`nP6.5 RC2 staging preflight passed." -ForegroundColor Green
    Write-Host 'Next: install the APK on the test device and complete docs/phase6_3_acceptance_results.md.'
}
finally {
    Set-Location $previousLocation
}
