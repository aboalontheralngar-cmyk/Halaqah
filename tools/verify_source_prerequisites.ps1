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

    # Flutter may uninstall an already-installed Android app after an
    # INSTALL_FAILED_VERSION_DOWNGRADE error, which also deletes its local
    # SQLite data. Refuse to proceed when a connected device has a newer
    # versionCode than this source tree.
    $versionLine = Get-Content -LiteralPath 'pubspec.yaml' |
        Where-Object { $_ -match '^version:\s*.+\+(\d+)\s*$' } |
        Select-Object -First 1
    $localVersionCode = if ($versionLine -and $versionLine -match '\+(\d+)\s*$') {
        [int]$Matches[1]
    } else {
        $null
    }
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    $adbPath = if ($adbCommand) { $adbCommand.Source } else { $null }
    if (-not $adbPath) {
        $sdkCandidates = @(
            $env:ANDROID_SDK_ROOT,
            $env:ANDROID_HOME,
            ((Get-Content -LiteralPath 'android/local.properties' -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^sdk\.dir=(.+)$' } |
                Select-Object -First 1) -replace '^sdk\.dir=', '')
        ) | Where-Object { $_ }
        foreach ($sdkRoot in $sdkCandidates) {
            $normalizedSdkRoot = $sdkRoot.Replace('\:', ':').Replace('\\', '\')
            $candidate = Join-Path $normalizedSdkRoot 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $candidate) {
                $adbPath = $candidate
                break
            }
        }
    }
    if ($adbPath -and $null -ne $localVersionCode) {
        $applicationId = if ($env:HALAQAH_APPLICATION_ID) {
            $env:HALAQAH_APPLICATION_ID.Trim()
        } else {
            'com.example.halaqah_teacher'
        }
        $deviceLines = & $adbPath devices | Select-Object -Skip 1
        $devices = @($deviceLines | ForEach-Object {
            if ($_ -match '^([^\s]+)\s+device$') { $Matches[1] }
        } | Where-Object { $_ })
        foreach ($device in $devices) {
            $packageDump = & $adbPath -s $device shell dumpsys package $applicationId 2>$null
            $installedVersionCode = $null
            foreach ($line in $packageDump) {
                if ($line -match 'versionCode=(\d+)') {
                    $installedVersionCode = [int]$Matches[1]
                    break
                }
            }
            if ($null -ne $installedVersionCode -and
                $installedVersionCode -gt $localVersionCode) {
                throw "Android data-safety stop: device $device has $applicationId versionCode $installedVersionCode, but this source is $localVersionCode. Increase the pubspec build number before flutter run. Do NOT let Flutter uninstall the newer app, because uninstalling deletes its local app data."
            }
        }
    }

    Write-Host 'Flutter source prerequisites passed.' -ForegroundColor Green
}
finally {
    Set-Location $previousLocation
}
