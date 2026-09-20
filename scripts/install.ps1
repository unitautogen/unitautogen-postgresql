#requires -Version 5
<#
  Install UnitAutogen for PostgreSQL on Windows.
  Downloads the latest release, verifies its SHA-256, and extracts it.

  Usage:
    powershell -ExecutionPolicy Bypass -File install.ps1 [-InstallDir <path>]
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME 'unitautogen')
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'unitautogen/unitautogen-postgresql'
Write-Host "Fetching the latest release of $repo ..."
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" `
    -Headers @{ 'User-Agent' = 'unitautogen-installer' }

$asset = $rel.assets | Where-Object { $_.name -like '*windows-x64.zip' } | Select-Object -First 1
$sums  = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }      | Select-Object -First 1
if (-not $asset) { throw 'No windows-x64.zip asset was found in the latest release.' }

$tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP ("uag_" + [guid]::NewGuid()))
try {
    $zip = Join-Path $tmp $asset.name
    Write-Host "Downloading $($asset.name) ..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip

    if ($sums) {
        $sumFile = Join-Path $tmp 'SHA256SUMS.txt'
        Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile
        $line = Select-String -Path $sumFile -Pattern ([regex]::Escape($asset.name)) | Select-Object -First 1
        if (-not $line) { throw "No checksum for $($asset.name) in SHA256SUMS.txt" }
        $expected = ($line.Line -split '\s+')[0].ToLower()
        $actual   = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLower()
        if ($expected -ne $actual) { throw "Checksum mismatch. expected $expected, got $actual" }
        Write-Host "Checksum verified."
    } else {
        Write-Warning "SHA256SUMS.txt not found in the release; skipping checksum verification."
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $InstallDir -Force
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

$exe = Join-Path $InstallDir 'unitautogen.exe'
Write-Host ""
Write-Host "Installed to $InstallDir"
Write-Host "Run it with:  `"$exe`" --help"
Write-Host "Tip: add $InstallDir to your PATH to call 'unitautogen' from anywhere."
