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
#   1. Verifies/installs git; verifies stock Lua (not a Teal/luarocks shim).
#   2. Clones the repo to a temp dir.
#   3. Installs to $env:LOCALAPPDATA\tpp (or $TPP_INSTALL_DIR).
#   4. Generates tpp.cmd in %LOCALAPPDATA%\Microsoft\WindowsApps with the
#      stock Lua path baked in. Removes any stale tpp.ps1 (which would
#      otherwise take precedence over tpp.cmd in PowerShell).
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
# HELPERS
# ============================================================

function Test-Command {
    param($name)
    $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# Refresh PATH in this process from Machine + User scopes. Called after
# installing a tool so we can find it without a new shell.
function Update-SessionPath {
    $machine = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path","User")
    $parts = @()
    if ($machine) { $parts += $machine }
    if ($user)    { $parts += $user }
    if ($parts.Count -gt 0) { $env:Path = ($parts -join ";") }
}

# Run a native command through cmd.exe so its stderr never becomes a
# PowerShell NativeCommandError. Returns output lines; sets $LASTEXITCODE.
function Invoke-NativeQuiet {
    param([string]$CommandLine, [switch]$Echo)
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & cmd.exe /d /c $CommandLine 2>&1
        if ($Echo) { $out | ForEach-Object { Write-Host "    $_" } }
        return $out
    } finally {
        $ErrorActionPreference = $prevEAP
    }
}

# Find a stock Lua interpreter. Skips anything under %USERPROFILE%\.local\bin
# (that's where luarocks/Teal shims live). Returns $null if none found.
function Find-StockLua {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\lua.exe"),
        "C:\Program Files\Lua\5.4\lua.exe",
        "C:\Program Files (x86)\Lua\5.4\lua.exe",
        "C:\Program Files\Lua\5.3\lua.exe",
        "C:\Program Files (x86)\Lua\5.3\lua.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    # Fall back to whatever `lua` resolves to, but only if it's not a shim.
    $cmd = Get-Command lua -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch '\\\.local\\bin\\')) {
        return $cmd.Source
    }
    return $null
}

# ============================================================
# PREFLIGHT / DEPS
# ============================================================

function Ensure-Git {
    if (Test-Command "git") { return }

    Write-Warn "git not found -- attempting to install automatically..."

    $installed = $false
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (Test-Command "winget") {
            Write-Log "Installing Git via winget (Git.Git)..."
            & winget install --id Git.Git -e --source winget `
                --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) { $installed = $true }
            Update-SessionPath
        }

        if (-not $installed -and (Test-Command "choco")) {
            Write-Log "winget unavailable or failed; trying Chocolatey..."
            & choco install git -y 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) { $installed = $true }
            Update-SessionPath
        }
    } finally {
        $ErrorActionPreference = $prevEAP
    }

    if (-not (Test-Command "git")) {
        Write-Host ""
        Write-Err "git is required but could not be installed automatically."
        Write-Host "  Install it manually, then re-run this installer:"
        Write-Host "    winget install Git.Git"
        Write-Host "    -- or download from https://git-scm.com/download/win"
        exit 1
    }

    Write-Ok "git installed: $((Get-Command git).Source)"
}

function Ensure-StockLua {
    $stock = Find-StockLua
    if ($stock) { return $stock }

    Write-Warn "stock Lua not found -- attempting to install via winget..."
    $installed = $false
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (Test-Command "winget") {
            & winget install --id DEVCOM.Lua -e --source winget `
                --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) { $installed = $true }
            Update-SessionPath
        }
    } finally {
        $ErrorActionPreference = $prevEAP
    }

    if ($installed) {
        $stock = Find-StockLua
        if ($stock) {
            Write-Ok "Lua installed: $stock"
            return $stock
        }
    }

    Write-Host ""
    Write-Err "stock Lua is required but could not be installed automatically."
    Write-Host "  Install it manually:"
    Write-Host "    winget install DEVCOM.Lua"
    Write-Host "  -- or download from https://luabinaries.sourceforge.net/"
    Write-Host ""
    Write-Host "  NOTE: do NOT use the 'lua' from a Teal / luarocks install"
    Write-Host "        (typically under %USERPROFILE%\.local\bin). It enforces"
    Write-Host "        Teal semantics and tpp's plain-Lua compiler will not load."
    exit 1
}

function Check-Deps {
    Write-Log "Checking dependencies..."

    Ensure-Git
    $script:StockLua = Ensure-StockLua

    # Warn if the ambient `lua` is a Teal/luarocks shim.
    $ambient = Get-Command lua -ErrorAction SilentlyContinue
    if ($ambient -and $ambient.Source -match '\\\.local\\bin\\lua\.exe$') {
        Write-Warn "the 'lua' on PATH is a Teal/luarocks shim:"
        Write-Host "    $($ambient.Source)"
        Write-Host "    tpp will use stock Lua at: $script:StockLua"
        Write-Host "    (this is fine; just don't try to run tpp-cli.lua with 'lua' directly)"
        Write-Host ""
    }

    $has_tl   = Test-Command "tl"
    $has_zip  = (Test-Command "zip") -or (Test-Command "tar")
    $has_love = Test-Command "love"

    if (-not $has_tl -or -not $has_zip -or -not $has_love) {
        Write-Warn "Optional dependencies missing:"
        if (-not $has_tl) {
            Write-Host "    tl    -- install with: winget install DEVCOM.Lua (includes luarocks)"
            Write-Host "             then: luarocks install tl"
            Write-Host "             see https://github.com/teal-language/tl#installation"
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

    # Run git through cmd.exe so its stderr ("Cloning into ...") is never
    # turned into a PowerShell NativeCommandError. Capture the exit code.
    $gitCmd = 'git clone --depth 1 --branch "{0}" "{1}" "{2}"' -f `
        $TppGitBranch, $TppGitRepo, $script:TempDir
    $out = Invoke-NativeQuiet -CommandLine $gitCmd -Echo
    $cloneExit = $LASTEXITCODE

    if ($cloneExit -ne 0 -or -not (Test-Path (Join-Path $script:TempDir ".git"))) {
        Write-Host ""
        Write-Host "  git output:" -ForegroundColor Yellow
        $out | ForEach-Object { Write-Host "    $_" }
        Die "git clone failed (exit $cloneExit). Check TPP_GIT_REPO and TPP_GIT_BRANCH."
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

    # Use single-quoted here-string so $ and % stay literal, then splice
    # the resolved stock-Lua path in explicitly.
    $stockLua = $script:StockLua
    if (-not $stockLua) { Die "internal error: stock Lua path was not resolved" }

    $cmdPath = Join-Path $TppBinDir "tpp.cmd"
    $cmdContent = @'
@echo off
setlocal
if "%TPP_PREFIX%"=="" set "TPP_PREFIX=__PREFIX__"
"__LUA__" "%TPP_PREFIX%\bin\tpp-cli.lua" %*
'@
    $cmdContent = $cmdContent.Replace('__PREFIX__', $TppInstallDir).Replace('__LUA__', $stockLua)
    Set-Content -Path $cmdPath -Value $cmdContent -Encoding ASCII

    # Remove any stale tpp.ps1 from a previous install. PowerShell prefers
    # .ps1 over .cmd, so a stale ps1 calling a bad Lua would silently win.
    $stalePs1 = Join-Path $TppBinDir "tpp.ps1"
    if (Test-Path $stalePs1) {
        Remove-Item -Force $stalePs1
        Write-Log "removed stale tpp.ps1 wrapper"
    }

    Write-Ok "Files installed"
    Write-Host "    wrapper: $cmdPath"
    Write-Host "    lua:     $stockLua"
}

function Verify {
    Write-Log "Verifying..."
    $cmd = Join-Path $TppBinDir "tpp.cmd"
    if (-not (Test-Path $cmd)) {
        Die "wrapper not found: $cmd"
    }

    # Capture stdout+stderr so we can print it if it fails.
    $output = Invoke-NativeQuiet -CommandLine "`"$cmd`" --help"
    $verifyExit = $LASTEXITCODE

    if ($verifyExit -ne 0) {
        Write-Err "installed tpp failed to run --help (exit $verifyExit)"
        Write-Host ""
        Write-Host "  Output:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "    $_" }
        Write-Host ""
        Write-Host "  Diagnostic info:" -ForegroundColor Yellow
        Write-Host "    wrapper:  $cmd"
        Write-Host "    prefix:   $TppInstallDir"
        Write-Host "    lua:      $script:StockLua"
        $cliPath = Join-Path $TppInstallDir "bin\tpp-cli.lua"
        $compPath = Join-Path $TppInstallDir "src\tpp.lua"
        Write-Host "    cli:      $cliPath  (exists: $(Test-Path $cliPath))"
        Write-Host "    compiler: $compPath  (exists: $(Test-Path $compPath))"
        Write-Host ""
        Die "verification failed; see output above."
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
