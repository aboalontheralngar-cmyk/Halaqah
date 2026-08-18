param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRef,
  [string]$AllowedOrigin = "https://halaqah-flame.vercel.app"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI was not found. Install it, run 'supabase login', then retry."
}
if ($AllowedOrigin -notmatch '^https://') {
  throw "AllowedOrigin must be an HTTPS production URL."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$websiteRoot = Join-Path $projectRoot "website"
$functionEntry = Join-Path $websiteRoot "supabase\functions\student-portal\index.ts"
if (-not (Test-Path $functionEntry)) {
  throw "student-portal Edge Function source was not found under website/supabase/functions/student-portal."
}

$pepperBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($pepperBytes)
} finally {
  $rng.Dispose()
}
$pepper = -join ($pepperBytes | ForEach-Object { $_.ToString("x2") })

Push-Location $websiteRoot
try {
  Write-Host "Updating student portal secrets..."
  & supabase secrets set `
    "PORTAL_ALLOWED_ORIGINS=$AllowedOrigin" `
    "PORTAL_RATE_LIMIT_PEPPER=$pepper" `
    --project-ref $ProjectRef
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to update Supabase Edge Function secrets."
  }

  Write-Host "Deploying student-portal Edge Function..."
  & supabase functions deploy student-portal `
    --project-ref $ProjectRef `
    --no-verify-jwt
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to deploy student-portal Edge Function."
  }

  Write-Host "Student portal deployed successfully."
} finally {
  Pop-Location
}
