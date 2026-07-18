[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,

    [string]$ChecksumPath,

    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedHash
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
    throw "Archive was not found: $ArchivePath"
}

if ($ChecksumPath -and $ExpectedHash) {
    throw 'Use either -ChecksumPath or -ExpectedHash, not both.'
}

$resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
$archiveName = Split-Path -Leaf $resolvedArchive

if (-not $ChecksumPath -and -not $ExpectedHash) {
    $ChecksumPath = "$resolvedArchive.sha256"
}

if ($ChecksumPath) {
    if (-not (Test-Path -LiteralPath $ChecksumPath -PathType Leaf)) {
        throw "Checksum file was not found: $ChecksumPath"
    }

    $checksumLine = Get-Content -LiteralPath $ChecksumPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1

    if ($checksumLine -notmatch '^\s*([A-Fa-f0-9]{64})\s+\*?(.+?)\s*$') {
        throw 'The checksum file is not in the expected SHA-256 format.'
    }

    $ExpectedHash = $Matches[1]
    $listedName = Split-Path -Leaf $Matches[2]
    if ($listedName -ne $archiveName) {
        throw "The checksum belongs to '$listedName', not '$archiveName'."
    }
}

$actualHash = (Get-FileHash -LiteralPath $resolvedArchive -Algorithm SHA256).Hash
if ($actualHash -ine $ExpectedHash) {
    Write-Host 'SHA-256 verification failed.' -ForegroundColor Red
    Write-Host "Expected: $($ExpectedHash.ToLowerInvariant())" -ForegroundColor Red
    Write-Host "Actual:   $($actualHash.ToLowerInvariant())" -ForegroundColor Red
    throw 'Do not extract or install this file. Download it again.'
}

Write-Host 'SHA-256 verification passed.' -ForegroundColor Green
Write-Host "File: $resolvedArchive" -ForegroundColor Green
Write-Host "Hash: $($actualHash.ToLowerInvariant())" -ForegroundColor Green
Write-Host 'The archive is intact and may now be extracted.' -ForegroundColor Green
