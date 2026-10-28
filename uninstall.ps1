# Teal++ (tpp) Windows uninstaller.
# Removes %LOCALAPPDATA%\tpp and tpp.cmd / tpp.ps1 from WindowsApps.
#
# Usage:
#   .\uninstall.ps1
#   .\uninstall.ps1 -Yes

param(
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# CONFIG — must match install.ps1
$TppInstallDir = if ($env:TPP_INSTALL_DIR) { $env:TPP_INSTALL_DIR } else {
    Join-Path $env:LOCALAPPDATA "tpp"
}
$TppBinDir = if ($env:TPP_BIN_DIR) { $env:TPP_BIN_DIR } else {
    Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
}

function Write-Log  { param($m) Write-Host "[*] " -ForegroundColor Blue -NoNewline; Write-Host $m }
function Write-Ok   { param($m) Write-Host "[+] " -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn { param($m) Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Err  { param($m) Write-Host "[x] " -ForegroundColor Red -NoNewline; Write-Host $m }
function Die        { param($m) Write-Err $m; exit 1 }

$targets = @()

if (Test-Path $TppInstallDir) {
    $targets += $TppInstallDir
}

foreach ($name in @("tpp.cmd", "tpp.ps1")) {
    $candidate = Join-Path $TppBinDir $name
    if (Test-Path $candidate) {
        # Verify it's ours — looks for the TPP_PREFIX marker we wrote
        $content = Get-Content -Raw -Path $candidate -ErrorAction SilentlyContinue
        if ($content -and $content -match "TPP_PREFIX") {
            $targets += $candidate
        } else {
            Write-Warn "Skipping $candidate — doesn't look like ours."
        }
    }
}

if ($targets.Count -eq 0) {
    Write-Log "Nothing to uninstall from:"
    Write-Host "    prefix:   $TppInstallDir"
    Write-Host "    wrapper:  $TppBinDir\tpp.cmd"
    exit 0
}

Write-Host ""
Write-Host "Teal++ uninstaller" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor DarkGray
Write-Host "  Will remove:"
foreach ($path in $targets) { Write-Host "    $path" }
Write-Host "=================================================" -ForegroundColor DarkGray
Write-Host ""

if (-not $Yes) {
    $response = Read-Host "Remove these files? [y/N]"
    if ($response -notmatch '^[yY]') { Write-Host "Aborted."; exit 0 }
}

foreach ($path in $targets) {
    Write-Log "Removing $path"
    Remove-Item -Recurse -Force -Path $path
}

Write-Host ""
Write-Ok "Uninstalled."
