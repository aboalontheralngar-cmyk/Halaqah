$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location

try {
    Set-Location $projectRoot
    & "$PSScriptRoot\verify_source_prerequisites.ps1"

    if ([string]::IsNullOrWhiteSpace($env:SUPABASE_URL)) {
        throw 'Set SUPABASE_URL for a production build.'
    }
    if ([string]::IsNullOrWhiteSpace($env:SUPABASE_PUBLISHABLE_KEY)) {
        throw 'Set SUPABASE_PUBLISHABLE_KEY for a production build.'
    }

    New-Item -ItemType Directory -Force -Path "build/symbols" | Out-Null

    flutter clean
    flutter pub get
    flutter build apk `
      --release `
      --split-per-abi `
      --obfuscate `
      --split-debug-info=build/symbols `
      --dart-define=HALAQAH_ENV=production `
      "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)" `
      "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($env:SUPABASE_PUBLISHABLE_KEY)"

    Write-Host "Split APK files: build/app/outputs/flutter-apk/"
    Write-Host "Archive build/symbols with this exact release for crash decoding."
}
finally {
    Set-Location $previousLocation
}
