[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipWeb,
    [switch]$SkipApk,
    [ValidateSet('release', 'debug')]
    [string]$ApkMode = 'release',
    [string]$SupabaseReadinessCsv,
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabasePublishableKey = $env:SUPABASE_PUBLISHABLE_KEY
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location
$startedAt = Get-Date
$apkArtifactPath = $null
$apkSha256 = $null
$apkSignatureStatus = 'not-checked'
$supabaseStatus = 'not-provided'

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
    Write-Host "Halaqah staging preflight — version $version" -ForegroundColor Green

    & "$PSScriptRoot\verify_source_prerequisites.ps1"

    if ($Clean) {
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('clean') -Label 'Flutter clean'
    }

    Invoke-CheckedCommand -Command 'flutter' -Arguments @('pub', 'get') -Label 'Flutter dependencies'
    Invoke-CheckedCommand -Command 'flutter' -Arguments @('analyze') -Label 'Flutter analyze'
    Invoke-CheckedCommand -Command 'flutter' -Arguments @('test') -Label 'Flutter tests'

    if (-not $SkipApk) {
        if ($ApkMode -eq 'release') {
            if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
                throw 'Release staging builds require SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (environment variables or parameters).'
            }
            $releaseArgs = @(
                'build', 'apk', '--release',
                '--dart-define=HALAQAH_ENV=staging',
                "--dart-define=SUPABASE_URL=$SupabaseUrl",
                "--dart-define=SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
            )
            Invoke-CheckedCommand -Command 'flutter' -Arguments $releaseArgs -Label 'Staging release APK'
        }
        else {
            Invoke-CheckedCommand -Command 'flutter' -Arguments @('build', 'apk', '--debug', '--dart-define=HALAQAH_ENV=development') -Label 'Staging debug APK'
        }
        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$ApkMode.apk"
        if (-not (Test-Path $apkPath)) {
            throw "APK was not created at $apkPath"
        }
        $artifactDirectory = Join-Path $projectRoot 'build\release-artifacts'
        New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
        $safeVersion = $version -replace '[^A-Za-z0-9._-]', '-'
        $artifactPath = Join-Path $artifactDirectory "halaqah-staging-$ApkMode-$safeVersion.apk"
        Copy-Item -LiteralPath $apkPath -Destination $artifactPath -Force
        $apkArtifactPath = $artifactPath

        $apkHash = Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
        $apkSha256 = $apkHash.Hash.ToLowerInvariant()
        $checksumPath = "$artifactPath.sha256"
        $checksumLine = "$apkSha256  $(Split-Path -Leaf $artifactPath)"
        Set-Content -LiteralPath $checksumPath -Value $checksumLine -Encoding ascii

        $apkSigner = Get-Command apksigner -ErrorAction SilentlyContinue
        if ($null -ne $apkSigner) {
            Invoke-CheckedCommand -Command $apkSigner.Source -Arguments @('verify', '--verbose', $artifactPath) -Label 'APK signature verification'
            $apkSignatureStatus = 'passed'
        }
        else {
            $apkSignatureStatus = 'skipped-apksigner-not-found'
            Write-Warning 'apksigner was not found; install Android build-tools to verify the APK signature locally.'
        }

        Write-Host "`nAPK: $artifactPath" -ForegroundColor Green
        Write-Host "SHA-256 file: $checksumPath" -ForegroundColor Green
        Write-Host "SHA-256: $($apkHash.Hash)" -ForegroundColor Green
    }

    if ($SupabaseReadinessCsv) {
        $resolvedCsv = Resolve-Path -LiteralPath $SupabaseReadinessCsv -ErrorAction Stop
        $readinessRows = @(Import-Csv -LiteralPath $resolvedCsv.Path)
        if ($readinessRows.Count -eq 0) {
            throw 'The Supabase readiness CSV is empty.'
        }
        foreach ($column in @('check_group', 'check_name', 'passed', 'details')) {
            if ($readinessRows[0].PSObject.Properties.Name -notcontains $column) {
                throw "Supabase readiness CSV is missing column: $column"
            }
        }
        $failedReadiness = @(
            $readinessRows | Where-Object {
                $_.passed.ToString().Trim().ToLowerInvariant() -ne 'true'
            }
        )
        $supabaseStatus = "$($readinessRows.Count - $failedReadiness.Count)/$($readinessRows.Count) passed"
        if ($failedReadiness.Count -gt 0) {
            $failedNames = ($failedReadiness | ForEach-Object { $_.check_name }) -join ', '
            throw "Supabase readiness failed: $failedNames"
        }
        Write-Host "Supabase readiness: $supabaseStatus" -ForegroundColor Green
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

    $completedAt = Get-Date
    $artifactDirectory = Join-Path $projectRoot 'build\release-artifacts'
    New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
    $safeVersion = $version -replace '[^A-Za-z0-9._-]', '-'
    $reportPath = Join-Path $artifactDirectory "halaqah-acceptance-$safeVersion.md"
    $reportLines = @(
        '# Halaqah release-candidate preflight',
        '',
        "- Version: $version",
        "- Started: $($startedAt.ToString('o'))",
        "- Completed: $($completedAt.ToString('o'))",
        '- Flutter analyze: passed',
        '- Flutter tests: passed',
        "- Web checks: $(if ($SkipWeb) { 'skipped' } else { 'passed' })",
        "- APK mode: $(if ($SkipApk) { 'skipped' } else { $ApkMode })",
        "- APK: $(if ($apkArtifactPath) { $apkArtifactPath } else { 'not-created' })",
        "- APK SHA-256: $(if ($apkSha256) { $apkSha256 } else { 'not-created' })",
        "- APK signature: $apkSignatureStatus",
        "- Supabase readiness: $supabaseStatus",
        '',
        'Physical device, two-device sync, portal isolation, and printer checks remain manual.'
    )
    Set-Content -LiteralPath $reportPath -Value $reportLines -Encoding utf8

    Write-Host "`nHalaqah staging preflight passed." -ForegroundColor Green
    Write-Host "Acceptance report: $reportPath" -ForegroundColor Green
    Write-Host 'Next: install the APK on the test device and complete docs/phase6_3_acceptance_results.md.'
}
finally {
    Set-Location $previousLocation
}
