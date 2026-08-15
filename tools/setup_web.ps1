[CmdletBinding()]
param(
    [switch]$CleanCache,
    [switch]$SkipBuild,
    [switch]$StartDev
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $projectRoot 'website'
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
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw 'Node.js was not found in PATH. Install the current Node.js LTS release, then reopen PowerShell.'
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'npm was not found in PATH. Reinstall Node.js with npm enabled, then reopen PowerShell.'
    }
    $npmCommand = if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
        'npm.cmd'
    } else {
        'npm'
    }
    if (-not (Test-Path (Join-Path $webRoot 'package-lock.json'))) {
        throw "website/package-lock.json is missing. Extract the complete source archive again."
    }

    Set-Location $webRoot
    Write-Host "Halaqah web setup" -ForegroundColor Green
    Write-Host "Node: $(& node --version)"
    Write-Host "npm:  $(& npm --version)"

    if ($CleanCache) {
        $nextCache = Join-Path $webRoot '.next'
        if (Test-Path $nextCache) {
            Remove-Item -LiteralPath $nextCache -Recurse -Force
            Write-Host 'Removed the stale .next cache.' -ForegroundColor Yellow
        }
    }

    $typeScriptCache = Join-Path $webRoot 'tsconfig.tsbuildinfo'
    if (Test-Path $typeScriptCache) {
        Remove-Item -LiteralPath $typeScriptCache -Force
        Write-Host 'Removed the stale TypeScript cache.' -ForegroundColor Yellow
    }

    Invoke-CheckedCommand -Command $npmCommand -Arguments @('ci') -Label 'Installing locked web dependencies'

    $requiredPaths = @(
        'node_modules/react/package.json',
        'node_modules/next/package.json',
        'node_modules/lucide-react/package.json',
        'node_modules/@types/react/index.d.ts',
        'node_modules/typescript/lib/tsserver.js'
    )
    $missingPaths = @($requiredPaths | Where-Object { -not (Test-Path (Join-Path $webRoot $_)) })
    if ($missingPaths.Count -gt 0) {
        throw "Web dependencies are incomplete after npm ci: $($missingPaths -join ', ')"
    }
    Write-Host 'Verified React, Next.js, Lucide, React types, and the workspace TypeScript server.' -ForegroundColor Green

    Invoke-CheckedCommand -Command $npmCommand -Arguments @('run', 'lint:ci') -Label 'Checking TypeScript and ESLint source'
    Invoke-CheckedCommand -Command $npmCommand -Arguments @('run', 'validate:all') -Label 'Running application contract checks'

    if (-not $SkipBuild) {
        Invoke-CheckedCommand -Command $npmCommand -Arguments @('run', 'build') -Label 'Building the production website'
    }

    # Touching tsconfig prompts an already-open VS Code window to reload the
    # project after node_modules and the workspace TypeScript SDK appear.
    (Get-Item (Join-Path $webRoot 'tsconfig.json')).LastWriteTime = Get-Date

    Write-Host "`nWeb setup completed successfully." -ForegroundColor Green
    Write-Host 'Close every VS Code window that opened this project, reopen Halaqah, then run "TypeScript: Restart TS Server" if any old red diagnostics remain.'
    Write-Host 'To start the site later: cd website; npm run dev'

    if ($StartDev) {
        Write-Host "`nStarting the local website at http://localhost:3000 ..." -ForegroundColor Cyan
        & $npmCommand run dev
    }
}
finally {
    Set-Location $previousLocation
}
