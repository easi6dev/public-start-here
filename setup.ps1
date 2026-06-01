<#
    TADA Backend - Windows Setup Script (Phase 1 + Phase 2)
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1 | iex
#>

# Wrap in scriptblock + try/catch so errors don't kill the PowerShell session (irm | iex safe)
& {
try {

Set-StrictMode -Version Latest

# --- Version banner (bump on every change; lets you tell a cached irm run from the latest) ---

$SetupVersion = "2026-06-01.4"
Write-Host "TADA setup.ps1  version $SetupVersion" -ForegroundColor Cyan

# --- Admin check ---

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then retry." -ForegroundColor Yellow
    return
}

# --- Prevent sleep/screen off during setup ---

try {
    $sleepApi = Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name "SleepAPI" -PassThru
    $sleepApi::SetThreadExecutionState(0x80000003) | Out-Null  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
} catch {}

# --- ExecutionPolicy ---

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "RemoteSigned" -or $currentPolicy -eq "Unrestricted" -or $currentPolicy -eq "Bypass") {
    Write-Host "    [SKIP] ExecutionPolicy already $currentPolicy" -ForegroundColor Yellow
}
else {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "    [OK] ExecutionPolicy set to RemoteSigned" -ForegroundColor Green
}

# --- Mac-style keyboard remapping (DISABLED — use optional/mac-keyboard.ps1 instead) ---
# To enable, uncomment the block below or run:
# irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/optional/mac-keyboard.ps1 | iex

# --- Helpers ---

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "    [SKIP] $Message" -ForegroundColor Yellow
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    [WARN] $Message" -ForegroundColor DarkYellow
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )
    $null = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Skip "$Name already installed"
    }
    else {
        Write-Host "    Installing $Name ..." -ForegroundColor White
        winget install --id $Id --exact --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$Name installed"
        }
        else {
            Write-Warn "$Name install may have failed (exit code: $LASTEXITCODE)"
        }
    }
}

# Strip null bytes from WSL UTF-16LE output
function Clean-WslOutput {
    param([object]$RawOutput)
    ($RawOutput | Out-String) -replace "`0","" | ForEach-Object { $_.Trim() }
}

# Parse JSON that may contain // or /* */ comments and trailing commas (e.g. Windows
# Terminal's default settings.json is JSONC). Windows PowerShell 5.1's ConvertFrom-Json
# throws on comments, so strip them first. The regex matches a whole JSON string as group 1
# BEFORE trying a comment, so "https://..." inside a value is never mistaken for a comment.
function ConvertFrom-Jsonc {
    param([string]$Text)
    $stripped = [regex]::Replace(
        $Text,
        '("(?:\\.|[^"\\])*")|//[^\r\n]*|/\*[\s\S]*?\*/',
        { param($m) if ($m.Groups[1].Success) { $m.Groups[1].Value } else { '' } }
    )
    $stripped = [regex]::Replace($stripped, ',(\s*[}\]])', '$1')
    $stripped | ConvertFrom-Json
}

# --- Phase 1: Windows Apps (winget) ---

Write-Step "Phase 1: Installing Windows applications via winget"

$guiApps = @(
    @{ Id = "JetBrains.IntelliJIDEA.Ultimate"; Name = "IntelliJ IDEA Ultimate" },
    @{ Id = "JetBrains.DataGrip";              Name = "DataGrip" },
    @{ Id = "JetBrains.Toolbox";               Name = "JetBrains Toolbox" },
    @{ Id = "Fork.Fork";                       Name = "Fork" },
    @{ Id = "Docker.DockerDesktop";             Name = "Docker Desktop" },
    @{ Id = "Anthropic.Claude";                 Name = "Claude" },
    @{ Id = "SlackTechnologies.Slack";          Name = "Slack" },
    @{ Id = "Figma.Figma";                      Name = "Figma" },
    @{ Id = "Google.Chrome";                    Name = "Google Chrome" },
    @{ Id = "Postman.Postman";                  Name = "Postman" },
    @{ Id = "MongoDB.Compass.Full";              Name = "MongoDB Compass" },
    @{ Id = "Google.AndroidStudio";              Name = "Android Studio" },
    @{ Id = "AgileBits.1Password";               Name = "1Password" },
    @{ Id = "Microsoft.PowerToys";               Name = "PowerToys" },
    @{ Id = "Cloudflare.Warp";                   Name = "Cloudflare WARP" }
)

$cliApps = @(
    @{ Id = "Microsoft.PowerShell";     Name = "PowerShell 7" },
    @{ Id = "Git.Git";                  Name = "Git" },
    @{ Id = "OpenJS.NodeJS.LTS";        Name = "Node.js LTS" },
    @{ Id = "Microsoft.OpenJDK.21";     Name = "OpenJDK 21" },
    @{ Id = "GitHub.cli";               Name = "GitHub CLI" },
    @{ Id = "jqlang.jq";                Name = "jq" },
    @{ Id = "Amazon.AWSCLI";            Name = "AWS CLI" },
    @{ Id = "Python.Python.3.12";       Name = "Python 3.12" },
    @{ Id = "astral-sh.uv";             Name = "uv" },
    @{ Id = "BurntSushi.ripgrep.MSVC";  Name = "ripgrep (rg)" },
    @{ Id = "sharkdp.fd";               Name = "fd" },
    @{ Id = "junegunn.fzf";             Name = "fzf" },
    @{ Id = "sharkdp.bat";              Name = "bat" },
    @{ Id = "ajeetdsouza.zoxide";       Name = "zoxide" },
    @{ Id = "dandavison.delta";         Name = "delta" },
    @{ Id = "eza-community.eza";        Name = "eza" }
)

# winget is bundled with Win11, but guard anyway: a missing winget.exe would throw a
# CommandNotFoundException inside Install-WingetPackage and abort the whole script.
$wingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if (-not $wingetAvailable) {
    Write-Warn "winget (App Installer) not found — skipping winget installs."
    Write-Warn "Install 'App Installer' from the Microsoft Store, then re-run."
}

if ($wingetAvailable) {
    Write-Host "`n  -- GUI Applications --" -ForegroundColor Magenta
    foreach ($app in $guiApps) {
        Install-WingetPackage -Id $app.Id -Name $app.Name
    }

    Write-Host "`n  -- CLI Tools --" -ForegroundColor Magenta
    foreach ($app in $cliApps) {
        Install-WingetPackage -Id $app.Id -Name $app.Name
    }
}

# sd, ktlint - not on winget, install via other means
Write-Step "Installing tools not available on winget"

# Refresh PATH for newly installed tools
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# sd (via GitHub API to resolve latest release asset)
if (Get-Command sd -ErrorAction SilentlyContinue) {
    Write-Skip "sd already installed"
}
else {
    Write-Host "    Installing sd via GitHub release ..." -ForegroundColor White
    try {
        $sdRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/chmln/sd/releases/latest" -UseBasicParsing
        $sdAsset = $sdRelease.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
        if ($sdAsset) {
            $sdZip = "$env:TEMP\sd.zip"
            $sdDir = "$env:LOCALAPPDATA\sd"
            Invoke-WebRequest -Uri $sdAsset.browser_download_url -OutFile $sdZip -UseBasicParsing
            Expand-Archive -Path $sdZip -DestinationPath $sdDir -Force
            # Find sd.exe (may be in a subdirectory)
            $sdExe = Get-ChildItem -Path $sdDir -Filter "sd.exe" -Recurse | Select-Object -First 1
            if ($sdExe -and $sdExe.DirectoryName -ne $sdDir) {
                Move-Item $sdExe.FullName $sdDir -Force
            }
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($currentPath -notlike "*$sdDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$sdDir", "User")
            }
            Remove-Item $sdZip -Force
            Write-OK "sd installed to $sdDir"
        }
        else {
            Write-Warn "Could not find sd Windows release asset"
        }
    }
    catch {
        Write-Warn "Failed to install sd: $_"
    }
}

# ktlint
if (Get-Command ktlint -ErrorAction SilentlyContinue) {
    Write-Skip "ktlint already installed"
}
else {
    Write-Host "    Installing ktlint ..." -ForegroundColor White
    $ktlintDir = "$env:LOCALAPPDATA\ktlint"
    New-Item -ItemType Directory -Path $ktlintDir -Force | Out-Null
    $ktlintUrl = "https://github.com/pinterest/ktlint/releases/latest/download/ktlint"
    Invoke-WebRequest -Uri $ktlintUrl -OutFile "$ktlintDir\ktlint" -UseBasicParsing
    Set-Content -Path "$ktlintDir\ktlint.bat" -Value "@java -jar `"%~dp0ktlint`" %*"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$ktlintDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$ktlintDir", "User")
    }
    Write-OK "ktlint installed to $ktlintDir"
}

# Claude Code (native install - recommended)
Write-Step "Installing Claude Code (native install)"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Claude Code already installed"
}
else {
    Write-Host "    Installing Claude Code via native installer ..." -ForegroundColor White
    $claudeInstaller = "$env:TEMP\claude-install.ps1"
    Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -OutFile $claudeInstaller -UseBasicParsing
    $claudeScript = Get-Content $claudeInstaller -Raw
    Invoke-Expression $claudeScript
    Remove-Item $claudeInstaller -Force -ErrorAction SilentlyContinue
    # Add Claude Code to PATH if not already there
    $claudeBinDir = Join-Path $env:USERPROFILE ".local\bin"
    if (Test-Path $claudeBinDir) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$claudeBinDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$claudeBinDir", "User")
            Write-OK "Added $claudeBinDir to PATH"
        }
    }
    Write-OK "Claude Code installed"
}

# Claude Code statusLine (shared team config)
Write-Step "Configuring Claude Code statusLine"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# statusline-command.sh — runs via Git Bash; needs jq + git on PATH (installed in Phase 1)
$statusLineScript = @'
#!/bin/sh
# Make dependencies resolvable regardless of the PATH Claude Code spawns us with:
#   /usr/bin, /mingw64/bin -> Git Bash coreutils + git (cat/awk/tr/cut/git)
#   WinGet Links           -> jq (winget installs jq ONLY here, not in Git Bash dirs);
#                             without this, jq fails and the statusline collapses to blank.
# On WSL the WinGet path simply doesn't exist (harmless no-op) and jq comes from the
# normal Linux PATH.
export PATH="/usr/bin:/mingw64/bin:$HOME/AppData/Local/Microsoft/WinGet/Links:$PATH"
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
thinking=$(echo "$input" | jq -r '.thinking.enabled // false')

# Git branch: run against cwd so it works in any repo regardless of JSON fields
git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Shorten cwd to the last N path segments (change PATH_SEGMENTS to taste)
PATH_SEGMENTS=2
disp_cwd=$(printf '%s' "$cwd" | tr '\\' '/' | awk -F'/' -v n="$PATH_SEGMENTS" '{
  out=""; start=NF-n+1; if(start<1) start=1;
  for(i=start;i<=NF;i++){ if($i!=""){ out=(out=="")?$i:out"/"$i } }
  if(start>1) out=".../" out;
  print out
}')

# Base: user@host:cwd  (hostname without -s for Git Bash compatibility)
short_host=$(hostname 2>/dev/null | cut -d. -f1)
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$(whoami)" "$short_host" "$disp_cwd"

# Git branch (magenta) — only when cwd is inside a git repo
if [ -n "$git_branch" ]; then
  printf ' \033[01;35m(%s)\033[00m' "$git_branch"
fi

# Model name (cyan)
if [ -n "$model" ]; then
  printf ' \033[01;36m[%s]\033[00m' "$model"
fi

# Context used percentage (bold yellow)
if [ -n "$ctx_pct" ]; then
  ctx_int=$(printf '%.0f' "$ctx_pct")
  printf ' \033[01;33m(%s%% ctx)\033[00m' "$ctx_int"
fi

# Effort level (dim yellow) — only when present
if [ -n "$effort" ]; then
  printf ' \033[00;33m[effort:%s]\033[00m' "$effort"
fi

# Thinking enabled (bold white) — only when true
if [ "$thinking" = "true" ]; then
  printf ' \033[01;37m[thinking]\033[00m'
fi
'@ -replace "`r`n", "`n"

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$statusLinePath = Join-Path $claudeDir "statusline-command.sh"
# Idempotent: only rewrite when content actually changed. Rewriting on every run would
# bump the mtime and make a live Claude Code re-spawn the statusline needlessly.
$existingSh = if (Test-Path $statusLinePath) { [System.IO.File]::ReadAllText($statusLinePath) } else { $null }
if ($existingSh -ceq $statusLineScript) {
    Write-Skip "statusline-command.sh already up to date"
} else {
    [System.IO.File]::WriteAllText($statusLinePath, $statusLineScript, $utf8NoBom)
    Write-OK "statusline-command.sh written to $statusLinePath"
}

# Claude Code runs the statusLine command THROUGH Git Bash on Windows (it auto-detects
# Git Bash), so just invoke `bash`. Do NOT embed an absolute
# "C:/Program Files/Git/bin/bash.exe" path: the space in "Program Files" gets mis-split
# when Claude Code re-parses the command for `bash -c`, and bash exits 126 (cannot execute)
# -> blank status line. A bare `bash` (no spaces, resolved on Git Bash's own PATH) plus a
# $HOME-relative script path sidesteps the space entirely and is user-agnostic.
$statusLineCommand = 'bash "$HOME/.claude/statusline-command.sh"'

# Merge statusLine into settings.json without clobbering existing settings
$settingsPath = Join-Path $claudeDir "settings.json"
$settingsExisted = Test-Path $settingsPath
$settings = $null
if ($settingsExisted) {
    try {
        $settings = [System.IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warn "settings.json is not valid JSON — leaving it as-is; add statusLine manually"
    }
}
# A present-but-unparseable file leaves $settings null after the try. Don't clobber it with
# a fresh object below (that would discard the user's settings and contradict the warning).
$settingsParseFailed = ($settingsExisted -and $null -eq $settings)
if ($null -eq $settings) {
    $settings = [PSCustomObject]@{}
}
if (-not $settingsParseFailed -and $settings -is [System.Management.Automation.PSCustomObject]) {
    # Idempotent: only rewrite settings.json when the statusLine actually differs.
    # Rewriting on every run makes a live Claude Code hot-reload its statusLine, which
    # is exactly what blanked it mid-setup. StrictMode-safe property probes throughout.
    $curStatusLine = if ($settings.PSObject.Properties['statusLine']) { $settings.statusLine } else { $null }
    $curType = if ($curStatusLine -and $curStatusLine.PSObject.Properties['type'])    { $curStatusLine.type }    else { $null }
    $curCmd  = if ($curStatusLine -and $curStatusLine.PSObject.Properties['command']) { $curStatusLine.command } else { $null }

    if ($curType -eq "command" -and $curCmd -eq $statusLineCommand) {
        Write-Skip "statusLine already configured in settings.json"
    } else {
        $statusLineObj = [PSCustomObject]@{
            type    = "command"
            command = $statusLineCommand
        }
        $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLineObj -Force
        $json = $settings | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)
        Write-OK "statusLine configured in settings.json"
    }
}

# Claude Code user-level CLAUDE.md (shared team defaults; WSL symlinks to this file)
Write-Step "Configuring Claude Code CLAUDE.md"

# Managed block is wrapped in markers so re-runs are idempotent and any user-authored
# content outside the markers is preserved.
# Markers (and the body below) are ASCII-only ON PURPOSE: `irm | iex` under Windows
# PowerShell 5.1 mis-decodes the downloaded UTF-8 (non-ASCII turns into '?'), so a marker
# containing an em-dash would be written corrupted and never match on the next run ->
# duplicate blocks. ASCII survives that path intact.
$claudeMdStart = "<!-- TADA-TEAM-DEFAULTS:START (managed by setup.ps1 - do not edit inside) -->"
$claudeMdEnd   = "<!-- TADA-TEAM-DEFAULTS:END -->"
$claudeMdBody = @'
<MOST_IMPORTANT_RULE>
Behavioral guidelines to reduce common LLM coding mistakes, derived from Andrej Karpathy's observations on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
</MOST_IMPORTANT_RULE>

<TERMINOLOGY>
- **CO Region**: US Colorado State
- **Slack Workspace URL**: `https://mvllabs.slack.com/`
- **Jira URL**: `https://mvlchain.atlassian.net/`
</TERMINOLOGY>

<CLI_Tools>
- Use `rg` instead of `grep` for faster text searches
- Use `fd` instead of `find` for file lookups
- Use `bat` instead of `cat` for file viewing
- Use `eza` instead of `ls` for directory listing
- Use `sd` instead of `sed` for text replacement
- Use `delta` for git diff viewing
- Use `fzf` for interactive fuzzy finding
- Use `zoxide` (`z`) instead of `cd` for directory navigation
</CLI_Tools>
'@ -replace "`r`n", "`n"

$claudeMdPath = Join-Path $claudeDir "CLAUDE.md"
$managedBlock = "$claudeMdStart`n$claudeMdBody`n$claudeMdEnd"
$existingMd = if (Test-Path $claudeMdPath) { [System.IO.File]::ReadAllText($claudeMdPath) -replace "`r`n", "`n" } else { "" }

# Strip ALL existing managed blocks (also self-heals duplicates from older buggy runs),
# then append exactly one fresh block. Idempotent AND propagates future content changes.
# Anchor the pattern on the ASCII-only sentinels (not the full marker): blocks written by
# the old buggy path have a corrupted '?'-mangled comment, and only the ASCII anchors are
# guaranteed to still match them so they get cleaned up too.
$blockPattern = '<!-- TADA-TEAM-DEFAULTS:START[\s\S]*?TADA-TEAM-DEFAULTS:END -->'
$cleaned = ([regex]::Replace($existingMd, $blockPattern, "")).TrimEnd()
$newMd = if ($cleaned) { "$cleaned`n`n$managedBlock`n" } else { "$managedBlock`n" }

if ($newMd -ceq $existingMd) {
    Write-Skip "Team defaults already up to date in CLAUDE.md"
} else {
    [System.IO.File]::WriteAllText($claudeMdPath, $newMd, $utf8NoBom)
    Write-OK "Team defaults written to $claudeMdPath"
}

# Flipper (mobile debugging, browser-based)
Write-Step "Installing Flipper server"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
$null = npm list -g flipper-server 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Skip "flipper-server already installed"
}
else {
    npm install -g flipper-server
    Write-OK "flipper-server installed (run: npx flipper-server)"
}

# --- Git Config ---

Write-Step "Configuring git defaults"
git config --global core.autocrlf input
git config --global core.eol lf
Write-OK "core.autocrlf=input, core.eol=lf"

# --- Windows developer-friendly settings ---

Write-Step "Configuring Windows developer settings"

$explorerAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$explorerCabinetState = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"

# File extensions visible
$val = (Get-ItemProperty -Path $explorerAdvanced -ErrorAction SilentlyContinue)
if ($null -ne $val -and $val.PSObject.Properties["HideFileExt"] -and $val.HideFileExt -eq 0) {
    Write-Skip "File extensions already visible"
} else {
    Set-ItemProperty -Path $explorerAdvanced -Name "HideFileExt" -Value 0
    Write-OK "File extensions now visible"
}

# Hidden files/folders visible (.git, .env, .vscode)
if ($null -ne $val -and $val.PSObject.Properties["Hidden"] -and $val.Hidden -eq 1) {
    Write-Skip "Hidden items already visible"
} else {
    Set-ItemProperty -Path $explorerAdvanced -Name "Hidden" -Value 1
    Write-OK "Hidden items now visible"
}

# Full path in Explorer title bar
if (-not (Test-Path $explorerCabinetState)) { New-Item -Path $explorerCabinetState -Force | Out-Null }
$cabVal = (Get-ItemProperty -Path $explorerCabinetState -ErrorAction SilentlyContinue)
if ($null -ne $cabVal -and $cabVal.PSObject.Properties["FullPathAddress"] -and $cabVal.FullPathAddress -eq 1) {
    Write-Skip "Full path in title bar already enabled"
} else {
    Set-ItemProperty -Path $explorerCabinetState -Name "FullPathAddress" -Value 1
    Write-OK "Full path in Explorer title bar enabled"
}

# Open Explorer to "This PC" instead of Home
if ($null -ne $val -and $val.PSObject.Properties["LaunchTo"] -and $val.LaunchTo -eq 1) {
    Write-Skip "Explorer already opens to This PC"
} else {
    Set-ItemProperty -Path $explorerAdvanced -Name "LaunchTo" -Value 1
    Write-OK "Explorer now opens to This PC"
}

# Developer Mode (symlinks without admin)
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue
if ($null -ne $devMode -and $devMode.PSObject.Properties["AllowDevelopmentWithoutDevLicense"] -and $devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
    Write-Skip "Developer Mode already enabled"
} else {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1
    Write-OK "Developer Mode enabled (symlinks without admin)"
}

# Long Paths enabled (prevents 260-char path limit errors in node_modules/Java)
$longPaths = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue
if ($null -ne $longPaths -and $longPaths.PSObject.Properties["LongPathsEnabled"] -and $longPaths.LongPathsEnabled -eq 1) {
    Write-Skip "Long Paths already enabled"
} else {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
    Write-OK "Long Paths enabled (no 260-char limit)"
}

# --- Windows Terminal: Shift+Enter -> newline ---
# Binds Shift+Enter to send ESC+CR, which Claude Code (and similar TUIs) read as
# "insert newline" instead of "submit". Windows Terminal captures the key before the
# shell, so this works for any profile (PowerShell, WSL, cmd) running inside WT. On
# Win11 22H2+ WT is the default terminal, so standalone PowerShell/WSL windows inherit
# it too. Git Bash (mintty) is its own emulator and is intentionally out of scope.

Write-Step "Configuring Windows Terminal Shift+Enter binding"
$wtDir      = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtSettings = Join-Path $wtDir "settings.json"
if (-not (Test-Path $wtDir)) {
    Write-Skip "Windows Terminal not present"
} else {
    try {
        # Missing file = WT never launched; an empty object is a valid partial settings
        # file that WT layers over its built-in defaults. Use ConvertFrom-Jsonc: WT's
        # default settings.json is JSONC (comments + trailing commas) and plain
        # ConvertFrom-Json throws on it under Windows PowerShell 5.1, which previously made
        # this whole step fail silently (caught below) so the binding was never written.
        $json = if (Test-Path $wtSettings) {
            ConvertFrom-Jsonc ([System.IO.File]::ReadAllText($wtSettings))
        } else { [pscustomobject]@{} }

        # Detect an existing binding in BOTH arrays: WT auto-migrates an inline
        # {command, keys} entry into actions[] (command) + keybindings[] (keys on re-save),
        # so checking only one array would let the binding be added twice on re-runs.
        # Guard property access: under StrictMode, reading $e.keys on an actions[] entry
        # that has no 'keys' (modern WT stores keys in keybindings[]) would throw.
        $has = $false
        foreach ($k in @('actions','keybindings')) {
            if ($json.PSObject.Properties[$k]) {
                foreach ($e in @($json.$k)) {
                    if ($null -ne $e -and $e.PSObject.Properties['keys'] -and $e.keys -eq 'shift+enter') { $has = $true }
                }
            }
        }

        if ($has) { Write-Skip "Shift+Enter binding already present" }
        else {
            if (-not $json.PSObject.Properties['actions']) {
                $json | Add-Member -NotePropertyName actions -NotePropertyValue @()
            }
            $esc = [char]27   # Windows PowerShell 5.1 has no `e escape; build ESC explicitly
            $binding = [pscustomobject]@{
                command = [pscustomobject]@{ action = 'sendInput'; input = ($esc + "`r") }
                keys    = 'shift+enter'
            }
            $json.actions = @($json.actions) + $binding
            # -Depth 32: the default of 2 truncates the nested profiles tree and corrupts
            # the file. WriteAllText with a BOM-less UTF-8 encoder per WT's requirement.
            $out = $json | ConvertTo-Json -Depth 32
            [System.IO.File]::WriteAllText($wtSettings, $out, (New-Object System.Text.UTF8Encoding $false))
            Write-OK "Shift+Enter -> newline binding added"
        }
    } catch { Write-Warn "Could not update Windows Terminal settings: $_" }
}

# --- hosts file (host.docker.internal) ---

Write-Step "Configuring hosts file"
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsFile -Raw -ErrorAction SilentlyContinue
if ($hostsContent -match "host\.docker\.internal") {
    Write-Skip "host.docker.internal already in hosts file"
}
else {
    Add-Content -Path $hostsFile -Value "`n127.0.0.1 host.docker.internal" -ErrorAction SilentlyContinue
    if ($?) {
        Write-OK "Added 127.0.0.1 host.docker.internal to hosts file"
    }
    else {
        Write-Warn "Could not modify hosts file — add manually: 127.0.0.1 host.docker.internal"
    }
    ipconfig /flushdns 2>&1 | Out-Null
    Write-OK "DNS cache flushed"
}

# --- Credential reminders ---

Write-Step "Manual setup reminders"
Write-Warn "Set these environment variables manually:"
Write-Host "    - GITHUB_USERNAME" -ForegroundColor White
Write-Host "    - GITHUB_TOKEN" -ForegroundColor White
Write-Host ""
Write-Warn "Docker Desktop: Enable WSL integration with Ubuntu-24.04 in Settings > Resources > WSL Integration"

# --- WSL 2 + Ubuntu 24.04 ---

Write-Step "Installing WSL 2 with Ubuntu 24.04"

# Check if WSL platform is installed via Windows feature (avoids wsl.exe garbled errors)
$wslFeature = $null
try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
} catch {}

$needsReboot = $false

if ($null -eq $wslFeature -or $wslFeature.State -ne "Enabled") {
    Write-Host "    WSL platform not found. Installing WSL ..." -ForegroundColor White
    wsl --install --no-distribution 2>&1 | Out-Null
    Write-OK "WSL platform installed"
    $needsReboot = $true
}
else {
    $wslInstalled = $null
    try { $wslInstalled = Clean-WslOutput (wsl --list --quiet 2>&1) } catch {}

    if ($wslInstalled -match "Ubuntu.?24\.04") {
        Write-Skip "Ubuntu 24.04 already installed on WSL"
    }
    else {
        Write-Host "    Installing Ubuntu 24.04 ..." -ForegroundColor White
        wsl --install -d Ubuntu-24.04 --no-launch
        Write-OK "Ubuntu-24.04 queued for install"
    }

    $wslReady = $null
    try { $wslReady = Clean-WslOutput (wsl -d Ubuntu-24.04 -- echo "ok" 2>&1) } catch {}
    if ($wslReady -ne "ok") {
        $needsReboot = $true
    }
}

if ($needsReboot) {
    # Open project page after reboot so user can re-run the setup command
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TadaSetupGuide" -Value "cmd /c start https://github.com/easi6dev/public-start-here"

    Write-Host ""
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host "    Reboot required to continue setup" -ForegroundColor Cyan
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    WSL needs a reboot to finish installing." -ForegroundColor White
    Write-Host "    After reboot, the setup guide will open in" -ForegroundColor White
    Write-Host "    your browser automatically." -ForegroundColor White
    Write-Host ""
    Write-Host "    Then open PowerShell as Admin and run the" -ForegroundColor White
    Write-Host "    same command again:" -ForegroundColor White
    Write-Host ""
    Write-Host '    irm "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1?t=$(Get-Random)" | iex' -ForegroundColor Green
    Write-Host ""
    Write-Host "    Already-installed items will be skipped." -ForegroundColor Gray
    Write-Host "    Only WSL services + repo cloning will run." -ForegroundColor Gray
    Write-Host ""
    $rebootNow = Read-Host "    Reboot now? (Y/n)"
    if ($rebootNow -ne "n" -and $rebootNow -ne "N") {
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Warn "Reboot whenever you're ready."
        Write-Warn "The setup guide will open automatically on next login."
    }
}

# --- .wslconfig ---

Write-Step "Configuring .wslconfig"

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Skip ".wslconfig already exists at $wslConfigPath"
}
else {
    $processors = 8
    $memory = "32GB"
    $wslConfigContent = @"
[wsl2]
processors = $processors
memory = $memory
networkingMode=mirrored
"@
    Set-Content -Path $wslConfigPath -Value $wslConfigContent
    Write-OK ".wslconfig created with defaults (processors=$processors, memory=$memory)"
    Write-Warn "Edit $wslConfigPath to adjust CPU/memory allocation for your machine"
}

# --- Phase 2: WSL internal setup ---

Write-Step "Phase 2: Setting up WSL services"

# Check if WSL is actually ready (may need reboot after first install)
$wslReady = Clean-WslOutput (wsl -d Ubuntu-24.04 -- echo "ok" 2>&1)
if ($wslReady -ne "ok") {
    Write-Warn "WSL is installed but not yet ready (reboot required)."
    Write-Warn "After rebooting, re-run this script to complete Phase 2 (WSL services)."
}
else {
    $setupWslUrl = "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup-wsl.sh"
    $setupWslPath = "$env:TEMP\setup-wsl.sh"

    Write-Host "    Downloading setup-wsl.sh ..." -ForegroundColor White
    Invoke-WebRequest -Uri $setupWslUrl -OutFile $setupWslPath -UseBasicParsing

    Write-Host "    Running setup-wsl.sh inside WSL ..." -ForegroundColor White
    # Convert Windows path to WSL path directly (wslpath loses backslashes)
    $driveLetter = $setupWslPath.Substring(0, 1).ToLower()
    $wslScriptPath = "/mnt/$driveLetter" + $setupWslPath.Substring(2).Replace('\', '/')
    # Run as regular user (UID 1000), not root — brew rejects root
    $wslUser = $null
    try {
        $rawUser = (wsl -d Ubuntu-24.04 -- id -un 1000 2>&1) -replace "`0",""
        $wslUser = ($rawUser | Out-String).Trim()
        if ($wslUser -match "no such user") { $wslUser = $null }
    } catch {}

    if (-not $wslUser) {
        Write-Host "    No regular WSL user found. Creating one ..." -ForegroundColor White
        $wslUser = "dev"
        wsl -d Ubuntu-24.04 -- bash -c "useradd -m -s /bin/bash -G sudo $wslUser && echo '${wslUser}:${wslUser}' | chpasswd && echo '$wslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$wslUser"
        Write-OK "WSL user '$wslUser' created (password: $wslUser, passwordless sudo)"
    }

    # setup-wsl.sh runs dozens of `sudo` calls non-interactively. A freshly created 'dev'
    # has passwordless sudo; a pre-existing UID-1000 user might not, which would make every
    # sudo fail under `set -e` (or hang). Ensure NOPASSWD before handing off.
    wsl -d Ubuntu-24.04 -u $wslUser -- sudo -n true 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Granting passwordless sudo to '$wslUser' ..." -ForegroundColor White
        wsl -d Ubuntu-24.04 -u root -- bash -c "echo '$wslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$wslUser && chmod 440 /etc/sudoers.d/$wslUser"
        Write-OK "Passwordless sudo configured for '$wslUser'"
    }

    Write-Host "    Running as WSL user: $wslUser" -ForegroundColor Gray
    wsl -d Ubuntu-24.04 -u $wslUser -- bash "$wslScriptPath"
}

# --- Phase 3: GitHub Auth + Clone Backend Repos ---
# Independent of WSL (clones into the Windows home dir and only needs gh from Phase 1), so it
# runs even when WSL still needs a reboot — otherwise a first run would leave repos uncloned.

Write-Step "Phase 3: GitHub authentication and repository cloning"

$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warn "GitHub CLI not found. Skipping Phase 3."
    Write-Host "    Install gh and run clone-repos.ps1 manually later." -ForegroundColor White
}
else {
    # Check auth by exit code (wrap in try/catch — gh stderr becomes ErrorRecord)
    $ghAuthed = $false
    try { $null = gh auth status 2>&1; if ($LASTEXITCODE -eq 0) { $ghAuthed = $true } } catch {}

    if (-not $ghAuthed) {
        Write-Host ""
        Write-Host "    ============================================" -ForegroundColor Cyan
        Write-Host "    GitHub Authentication" -ForegroundColor Cyan
        Write-Host "    ============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    A browser will open to GitHub." -ForegroundColor White
        Write-Host "    Enter the device code shown below and click Authorize." -ForegroundColor White
        Write-Host ""
        $env:GH_PROMPT_DISABLED = "1"
        gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
        $env:GH_PROMPT_DISABLED = ""
    }

    # Re-check auth after login attempt
    $ghAuthed = $false
    try { $null = gh auth status 2>&1; if ($LASTEXITCODE -eq 0) { $ghAuthed = $true } } catch {}

    if ($ghAuthed) {
        Write-OK "GitHub authenticated"

        # --- Git identity (user.name / user.email) — applied to BOTH Windows and WSL ---
        # Prompted here, AFTER gh auth, so we can prefill from the authenticated account.
        # gh api user gives .name/.login (always) and .email (often null when the user keeps
        # their email private). Enter accepts the [default]; typing a value overrides it.
        # Identity is the only part of .gitconfig safe to share across OSes, so we set the
        # same value in each side's own config rather than symlinking the whole file.
        Write-Step "Configuring git identity"
        $gitName  = git config --global user.name  2>$null
        $gitEmail = git config --global user.email 2>$null
        if ($gitName -and $gitEmail) {
            # Already set on Windows — reuse those values (no prompt), still mirror to WSL below.
            Write-Skip "git identity already set on Windows (name='$gitName', email='$gitEmail')"
        }
        else {
            $ghName = $null; $ghEmail = $null
            try {
                $ghUser  = gh api user 2>$null | ConvertFrom-Json
                $ghName  = $ghUser.name
                $ghEmail = $ghUser.email
                if (-not $ghName) { $ghName = $ghUser.login }
            } catch {}

            $defName  = if ($ghName)  { $ghName }  else { $gitName }
            $defEmail = if ($ghEmail) { $ghEmail } else { $gitEmail }

            $nPrompt = if ($defName) { "    git user.name [$defName]" } else { "    git user.name" }
            $inName  = (Read-Host $nPrompt).Trim()
            if (-not $inName) { $inName = $defName }

            # email is commonly null on gh (private) -> no default, user types it directly
            $ePrompt = if ($defEmail) { "    git user.email [$defEmail]" } else { "    git user.email" }
            $inEmail = (Read-Host $ePrompt).Trim()
            if (-not $inEmail) { $inEmail = $defEmail }

            if ($inName)  { git config --global user.name  $inName;  $gitName  = $inName }
            if ($inEmail) { git config --global user.email $inEmail; $gitEmail = $inEmail }
            Write-OK "git identity set on Windows (name='$gitName', email='$gitEmail')"
        }

        # Mirror the resolved identity into WSL's own ~/.gitconfig (git installed in Phase 2).
        # Always run so a previously Windows-only config still propagates to WSL on re-runs.
        if ($gitName)  { wsl -d Ubuntu-24.04 -u $wslUser -- git config --global user.name  "$gitName"  2>$null }
        if ($gitEmail) { wsl -d Ubuntu-24.04 -u $wslUser -- git config --global user.email "$gitEmail" 2>$null }
        if ($gitName -and $gitEmail) { Write-OK "git identity mirrored to WSL user '$wslUser'" }

        Write-Host "    Downloading clone script from private repo ..." -ForegroundColor White
        $cloneScript = gh api "repos/easi6dev/start-here/contents/teams/server/clone-repos.ps1" --jq ".content" 2>&1
        $ghExitCode = $LASTEXITCODE
        if ($ghExitCode -eq 0) {
            $rawContent = ($cloneScript -join "") -replace "`r","" -replace "`n",""
            $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($rawContent))
            $cloneScriptPath = "$env:TEMP\clone-repos.ps1"
            Set-Content -Path $cloneScriptPath -Value $decoded -Encoding UTF8
            Write-OK "Clone script downloaded"

            Write-Host "    Running clone-repos.ps1 ..." -ForegroundColor White
            & $cloneScriptPath
        }
        else {
            Write-Warn "Could not fetch clone script. Check your GitHub access to easi6dev/start-here."
            Write-Host "    You can run it manually later:" -ForegroundColor White
            Write-Host "    gh auth login && gh repo clone easi6dev/start-here && .\start-here\teams\server\clone-repos.ps1" -ForegroundColor White
        }
    }
    else {
        Write-Warn "Not authenticated with GitHub. Skipping Phase 3."
        Write-Host "    Run manually later: gh auth login && gh repo clone easi6dev/start-here" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Things to do manually:" -ForegroundColor Magenta
Write-Host ""
Write-Host "  1. Chrome" -ForegroundColor Yellow
Write-Host "     - Open Chrome and sign in with your Google account" -ForegroundColor White
Write-Host "     - Set Chrome as your default browser (Settings > Default browser)" -ForegroundColor White
Write-Host ""
Write-Host "  2. Docker Desktop" -ForegroundColor Yellow
Write-Host "     - Open Docker Desktop" -ForegroundColor White
Write-Host "     - Settings > Resources > WSL Integration > Enable Ubuntu-24.04" -ForegroundColor White
Write-Host ""
Write-Host "  3. Cloudflare WARP" -ForegroundColor Yellow
Write-Host "     - Open Cloudflare WARP and configure with the team VPN settings" -ForegroundColor White
Write-Host "     - Access launcher: https://mvlchain.cloudflareaccess.com/#/Launcher" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Environment Variables" -ForegroundColor Yellow
Write-Host "     - GITHUB_USERNAME: your GitHub username" -ForegroundColor White
Write-Host "     - GITHUB_TOKEN: create a PAT with 'repo' + 'read:packages' scopes" -ForegroundColor White
Write-Host "       https://github.com/settings/tokens" -ForegroundColor Gray
Write-Host ""
Write-Host "  5. Slack" -ForegroundColor Yellow
Write-Host "     - Open Slack and sign in to your workspace" -ForegroundColor White
Write-Host ""
Write-Host "  6. IntelliJ IDEA" -ForegroundColor Yellow
Write-Host "     - Open IntelliJ and sign in to your JetBrains account" -ForegroundColor White
Write-Host "     - Open a backend project from ~/backend/ to verify setup" -ForegroundColor White
Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR: Script failed at:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
}
} # end of & { wrapper
