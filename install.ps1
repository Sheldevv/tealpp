# Teal++ (tpp) Windows installer
# PowerShell 5.1+ (default on Windows 10/11).
#
# Run from PowerShell:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\install.ps1
#
# Or override defaults via env vars:
#   $env:TPP_GIT_REPO = "https://github.com/me/tealpp.git"
#   $env:TPP_INSTALL_DIR = "D:\tpp"
#   .\install.ps1
#
# What it does:
#   1. Verifies git, lua, tl, zip are available (helpful errors otherwise).
#   2. Clones the repo to a temp dir.
#   3. Installs to $env:LOCALAPPDATA\tpp (or $TPP_INSTALL_DIR).
#   4. Generates tpp.cmd + tpp.ps1 wrappers in %LOCALAPPDATA%\Microsoft\WindowsApps
#      (a directory that's already on PATH by default on Win10+).
#   5. Verifies `tpp --help` runs.

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIG
# ============================================================

$TppGitRepo   = if ($env:TPP_GIT_REPO)   { $env:TPP_GIT_REPO }   else { "https://github.com/Sheldevv/tealpp.git" }
$TppGitBranch = if ($env:TPP_GIT_BRANCH) { $env:TPP_GIT_BRANCH } else { "main" }
$TppInstallDir = if ($env:TPP_INSTALL_DIR) {
    $env:TPP_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "tpp"
}

# Where the tpp.cmd wrapper goes.
# %LOCALAPPDATA%\Microsoft\WindowsApps is on PATH by default on Win10+.
$TppBinDir = if ($env:TPP_BIN_DIR) {
    $env:TPP_BIN_DIR
} else {
    Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
}

# ============================================================
# COLORS
# ============================================================

function Write-Log  { param($m) Write-Host "[*] " -ForegroundColor Blue -NoNewline; Write-Host $m }
function Write-Ok   { param($m) Write-Host "[+] " -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn { param($m) Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Err  { param($m) Write-Host "[x] " -ForegroundColor Red -NoNewline; Write-Host $m }
function Die        { param($m) Write-Err $m; exit 1 }

# ============================================================
# PREFLIGHT / DEPS
# ============================================================

function Test-Command {
    param($name)
    $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Check-Deps {
    Write-Log "Checking dependencies..."

    $missing = @()
    foreach ($cmd in @("git", "lua")) {
        if (-not (Test-Command $cmd)) { $missing += $cmd }
    }

    if ($missing.Count -gt 0) {
        Write-Err ("Missing required tools: " + ($missing -join ", "))
        Write-Host ""
        Write-Host "  Install with winget:"
        Write-Host "    winget install Git.Git"
        Write-Host "    winget install DevCom.Lua"
        Write-Host ""
        Write-Host "  Or download manually:"
        Write-Host "    git:  https://git-scm.com/download/win"
        Write-Host "    lua:  https://github.com/rjpcomputing/luaforwindows/releases"
        Write-Host ""
        exit 1
    }

    $has_tl   = Test-Command "tl"
    $has_zip  = (Test-Command "zip") -or (Test-Command "tar")
    $has_love = Test-Command "love"

    if (-not $has_tl -or -not $has_zip -or -not $has_love) {
        Write-Warn "Optional dependencies missing:"
        if (-not $has_tl) {
            Write-Host "    tl    -- install with: luarocks install tl"
            Write-Host "             (needs lua + luarocks + a C toolchain;"
            Write-Host "              see https://github.com/teal-language/tl#installation)"
        }
        if (-not $has_zip) {
            Write-Host "    zip   -- install with: winget install 7zip.7zip"
            Write-Host "             (or use Windows's built-in tar: 'tar -a -c -f out.zip *')"
        }
        if (-not $has_love) {
            Write-Host "    love  -- install with: winget install Love2D.Love2D"
            Write-Host "             or download from https://love2d.org"
        }
        Write-Host ""
    }

    Write-Ok "Dependencies OK"
}

# ============================================================
# FETCH / INSTALL
# ============================================================

function Fetch-Repo {
    $script:TempDir = Join-Path $env:TEMP ("tpp-install-" + [guid]::NewGuid().ToString("N").Substring(0,8))
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    Write-Log "Cloning $TppGitRepo (branch: $TppGitBranch)..."
    $clone = & git clone --depth 1 --branch $TppGitBranch $TppGitRepo $script:TempDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $clone
        Die "git clone failed. Check TPP_GIT_REPO and TPP_GIT_BRANCH."
    }

    $mustExist = @(
        "src/tpp.lua",
        "gamekit/init.lua",
        "bin/tpp-cli.lua"
    )
    foreach ($path in $mustExist) {
        if (-not (Test-Path (Join-Path $script:TempDir $path))) {
            Die "repo missing $path"
        }
    }
    Write-Ok "Fetched"
}

function Install-Files {
    $updating = ""
    if (Test-Path $TppInstallDir) { $updating = " (updating existing)" }
    Write-Log "Installing to $TppInstallDir$updating"

    New-Item -ItemType Directory -Path $TppInstallDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $TppInstallDir "bin") -Force | Out-Null
    New-Item -ItemType Directory -Path $TppBinDir -Force | Out-Null

    # Clean previous tpp-owned files
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "bin")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "src")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "gamekit")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "gamekit.d.tl")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "PACKAGING.md")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $TppInstallDir "GETTING-STARTED.md")

    New-Item -ItemType Directory -Path (Join-Path $TppInstallDir "bin") -Force | Out-Null

    Copy-Item -Recurse -Force (Join-Path $script:TempDir "src")     (Join-Path $TppInstallDir "src")
    Copy-Item -Recurse -Force (Join-Path $script:TempDir "gamekit") (Join-Path $TppInstallDir "gamekit")
    Copy-Item -Force (Join-Path $script:TempDir "bin/tpp-cli.lua")  (Join-Path $TppInstallDir "bin/tpp-cli.lua")

    foreach ($f in @("gamekit.d.tl", "PACKAGING.md", "GETTING-STARTED.md")) {
        $src = Join-Path $script:TempDir $f
        if (Test-Path $src) { Copy-Item -Force $src (Join-Path $TppInstallDir $f) }
    }

    # Generate tpp.cmd (works in cmd.exe, PowerShell, double-click)
    $cmdPath = Join-Path $TppBinDir "tpp.cmd"
    $cmdContent = @"
@echo off
setlocal
if "%TPP_PREFIX%"=="" set "TPP_PREFIX=$TppInstallDir"
lua "%TPP_PREFIX%\bin\tpp-cli.lua" %*
"@
    Set-Content -Path $cmdPath -Value $cmdContent -Encoding ASCII

    # Generate tpp.ps1 for PowerShell users who prefer it
    $ps1Path = Join-Path $TppBinDir "tpp.ps1"
    $ps1Content = @"
#!/usr/bin/env pwsh
`$ErrorActionPreference = "Stop"
if (-not `$env:TPP_PREFIX) { `$env:TPP_PREFIX = "$TppInstallDir" }
& lua "`$env:TPP_PREFIX\bin\tpp-cli.lua" @args
exit `$LASTEXITCODE
"@
    Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

    Write-Ok "Files installed"
}

function Verify {
    Write-Log "Verifying..."
    $cmd = Join-Path $TppBinDir "tpp.cmd"
    & cmd.exe /c "`"$cmd`" --help >NUL 2>NUL"
    if ($LASTEXITCODE -ne 0) {
        Die "installed tpp failed to run --help"
    }
    Write-Ok "tpp --help works"
}

function Path-Hint {
    $inPath = ($env:PATH -split ";" | Where-Object { $_ -eq $TppBinDir }).Count -gt 0
    if ($inPath) { return }

    Write-Host ""
    Write-Warn "$TppBinDir is not on PATH."
    Write-Host ""
    Write-Host "  Windows 10+ usually includes %LOCALAPPDATA%\Microsoft\WindowsApps on PATH"
    Write-Host "  by default. If it's missing, add this to your user PATH:"
    Write-Host ""
    Write-Host "    $TppBinDir"
    Write-Host ""
    Write-Host "  From PowerShell (elevated not required):"
    Write-Host "    [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$TppBinDir', 'User')"
    Write-Host ""
}

# ============================================================
# MAIN
# ============================================================

function Main {
    Write-Host ""
    Write-Host "Teal++ (tpp) installer" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host "  repo:     $TppGitRepo"
    Write-Host "  branch:   $TppGitBranch"
    Write-Host "  prefix:   $TppInstallDir"
    Write-Host "  wrapper:  $TppBinDir\tpp.cmd"
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host ""

    Check-Deps
    Fetch-Repo
    Install-Files
    Verify
    Path-Hint

    Write-Host ""
    Write-Ok "Done."
    Write-Host ""
    Write-Host "  Try it:"
    Write-Host "    tpp --help"
    Write-Host "    cd C:\path\to\game"
    Write-Host "    tpp love main.tpp"
    Write-Host ""
    Write-Host "  Docs:"
    Write-Host "    $TppInstallDir\GETTING-STARTED.md"
    Write-Host "    $TppInstallDir\PACKAGING.md"
    Write-Host ""
}

Main

# Cleanup temp
if ($script:TempDir -and (Test-Path $script:TempDir)) {
    Remove-Item -Recurse -Force $script:TempDir
}
