param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRef,
  [string]$AllowedOrigin = "https://halaqah-flame.vercel.app"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI غير موجود. ثبته وسجل الدخول ثم أعد تشغيل هذا السكربت."
}
if ($AllowedOrigin -notmatch '^https://') {
  throw "AllowedOrigin يجب أن يكون رابط HTTPS للإنتاج."
}

$pepperBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($pepperBytes)
} finally {
  $rng.Dispose()
}
$pepper = -join ($pepperBytes | ForEach-Object { $_.ToString("x2") })

Write-Host "Linking Supabase project..."
supabase link --project-ref $ProjectRef

Write-Host "Updating portal secrets..."
supabase secrets set "PORTAL_ALLOWED_ORIGINS=$AllowedOrigin" "PORTAL_RATE_LIMIT_PEPPER=$pepper"

Write-Host "Deploying student-portal Edge Function..."
supabase functions deploy student-portal --no-verify-jwt

Write-Host "Student portal deployed successfully."
