#requires -Version 5
<#
  Install UnitAutogen for PostgreSQL on Windows (x64).
  Downloads the newest release (pre-releases included), verifies its SHA-256, and extracts it.

  Usage:
    powershell -ExecutionPolicy Bypass -File install.ps1 [-InstallDir <path>]
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME 'unitautogen')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'      # the progress bar makes Invoke-WebRequest very slow on PowerShell 5
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'unitautogen/unitautogen-postgresql'
$headers = @{ 'User-Agent' = 'unitautogen-installer'; 'Accept' = 'application/vnd.github+json' }

Write-Host "Fetching the newest release of $repo ..."
# /releases lists every published release, newest first, pre-releases included.
# (/releases/latest skips pre-releases, so it is not used.)
try {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=20" -Headers $headers
} catch {
    throw "Could not reach the GitHub API. Download the build by hand from https://github.com/$repo/releases"
}

# The newest release that has a Windows build.
$rel = $releases | Where-Object { -not $_.draft -and ($_.assets | Where-Object { $_.name -like 'dist-Windows-*.zip' }) } |
       Select-Object -First 1
if (-not $rel) { throw 'No dist-Windows-<version>.zip asset was found in any release.' }

$asset = $rel.assets | Where-Object { $_.name -like 'dist-Windows-*.zip' } | Select-Object -First 1
$sums  = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }      | Select-Object -First 1

$tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP ("uag_" + [guid]::NewGuid()))
try {
    $zip = Join-Path $tmp $asset.name
    Write-Host "Release $($rel.tag_name): downloading $($asset.name) ..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing

    if ($sums) {
        $sumFile = Join-Path $tmp 'SHA256SUMS.txt'
        Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile -UseBasicParsing
        $line = Get-Content $sumFile | Where-Object { ($_ -split '\s+')[-1].TrimStart('*') -eq $asset.name } | Select-Object -First 1
        if (-not $line) { throw "SHA256SUMS.txt in release $($rel.tag_name) has no line for $($asset.name)." }
        $expected = ($line -split '\s+')[0].ToLower()
        $actual   = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLower()
        if ($expected -ne $actual) { throw "Checksum mismatch for $($asset.name). Expected $expected, got $actual." }
        Write-Host "Checksum verified."
    } else {
        Write-Warning "Release $($rel.tag_name) has no SHA256SUMS.txt; the archive was not verified."
    }

    # The zip may hold the files at its root or inside a dist-Windows-<version> folder.
    $x = Join-Path $tmp 'x'
    Expand-Archive -Path $zip -DestinationPath $x -Force
    $found = Get-ChildItem -Path $x -Recurse -Filter 'unitautogen.exe' | Select-Object -First 1
    if (-not $found) { throw "unitautogen.exe not found in $($asset.name)" }
    $src = $found.DirectoryName

    # The build folder carries its own SHA256SUMS for the exe; check it too.
    $inner = Join-Path $src 'SHA256SUMS'
    if (Test-Path $inner) {
        foreach ($l in Get-Content $inner) {
            if (-not $l.Trim()) { continue }
            $parts = $l -split '\s+', 2
            $f = Join-Path $src $parts[1].TrimStart('*')
            if ((Get-FileHash -Algorithm SHA256 -Path $f).Hash.ToLower() -ne $parts[0].ToLower()) {
                throw "$($parts[1]) does not match the SHA256SUMS inside $($asset.name)."
            }
        }
        Write-Host "Executable checksum verified."
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $InstallDir -Recurse -Force
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# Clear the "downloaded from the internet" mark so Windows does not block the exe.
Get-ChildItem -Path $InstallDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

$exe = Join-Path $InstallDir 'unitautogen.exe'
$ver = $null
try { $ver = (& $exe --version 2>$null) } catch { }
if (-not $ver) { Write-Warning "'$exe --version' did not run. Windows SmartScreen or antivirus may have blocked it; see the README." }

Write-Host ""
Write-Host "Installed $(if ($ver) { $ver } else { $rel.tag_name }) to $InstallDir"
Write-Host "Run it with:  `"$exe`" --help"
if (($env:Path -split ';') -notcontains $InstallDir) {
    Write-Host "Tip: add $InstallDir to your PATH to call 'unitautogen' from anywhere."
}
