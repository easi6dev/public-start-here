<#
    TADA Backend - Reset Script
    Removes everything installed by setup.ps1 so you can start fresh.
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/reset.ps1 | iex
#>

& {
try {

Set-StrictMode -Version Latest

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then retry." -ForegroundColor Yellow
    return
}

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

function Uninstall-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )
    $null = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Uninstalling $Name ..." -ForegroundColor White
        winget uninstall --id $Id --silent
        Write-OK "$Name uninstalled"
    }
    else {
        Write-Skip "$Name not installed"
    }
}

# --- Confirm ---

Write-Host ""
Write-Host "============================================" -ForegroundColor Red
Write-Host "  TADA Backend - FULL RESET" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will remove:" -ForegroundColor Yellow
Write-Host "  - All winget-installed GUI apps and CLI tools" -ForegroundColor White
Write-Host "  - Service port environment variables" -ForegroundColor White
Write-Host "  - .wslconfig" -ForegroundColor White
Write-Host "  - sd, ktlint local installs" -ForegroundColor White
Write-Host "  - Claude Code" -ForegroundColor White
Write-Host "  - git global config (autocrlf, eol, delta pager)" -ForegroundColor White
Write-Host "  - fork/zoxide shell launchers (PowerShell, Git Bash, WSL)" -ForegroundColor White
Write-Host "  - CLAUDE.md team-defaults block (your own content kept)" -ForegroundColor White
Write-Host "  - Windows Terminal default profile + Shift+Enter binding" -ForegroundColor White
Write-Host "  - ~/backend/ directory (all cloned repos)" -ForegroundColor White
Write-Host "  - WSL Ubuntu-24.04 (optional, will ask)" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to cancel, or" -ForegroundColor Yellow
Read-Host "Press Enter to continue"

# --- Uninstall winget apps ---

Write-Step "Uninstalling winget applications"

$allApps = @(
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
    @{ Id = "Cloudflare.Warp";                   Name = "Cloudflare WARP" },
    @{ Id = "Microsoft.PowerShell";              Name = "PowerShell 7" },
    @{ Id = "Git.Git";                          Name = "Git" },
    @{ Id = "OpenJS.NodeJS.LTS";                Name = "Node.js LTS" },
    @{ Id = "Microsoft.OpenJDK.21";             Name = "OpenJDK 21" },
    @{ Id = "GitHub.cli";                       Name = "GitHub CLI" },
    @{ Id = "jqlang.jq";                        Name = "jq" },
    @{ Id = "Amazon.AWSCLI";                    Name = "AWS CLI" },
    @{ Id = "Python.Python.3.12";               Name = "Python 3.12" },
    @{ Id = "astral-sh.uv";                     Name = "uv" },
    @{ Id = "BurntSushi.ripgrep.MSVC";          Name = "ripgrep (rg)" },
    @{ Id = "sharkdp.fd";                       Name = "fd" },
    @{ Id = "junegunn.fzf";                     Name = "fzf" },
    @{ Id = "sharkdp.bat";                      Name = "bat" },
    @{ Id = "ajeetdsouza.zoxide";               Name = "zoxide" },
    @{ Id = "dandavison.delta";                 Name = "delta" },
    @{ Id = "eza-community.eza";                Name = "eza" }
)

foreach ($app in $allApps) {
    Uninstall-WingetPackage -Id $app.Id -Name $app.Name
}

# --- Remove sd, ktlint ---

Write-Step "Removing sd and ktlint"

$sdDir = "$env:LOCALAPPDATA\sd"
$ktlintDir = "$env:LOCALAPPDATA\ktlint"

if (Test-Path $sdDir) {
    Remove-Item $sdDir -Recurse -Force
    Write-OK "sd removed"
}
else { Write-Skip "sd not found" }

if (Test-Path $ktlintDir) {
    Remove-Item $ktlintDir -Recurse -Force
    Write-OK "ktlint removed"
}
else { Write-Skip "ktlint not found" }

# Clean PATH entries (sd, ktlint, Claude Code)
$claudeBinDir = Join-Path $env:USERPROFILE ".local\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$cleanedPath = ($userPath -split ";" | Where-Object {
    $_ -notlike "*$env:LOCALAPPDATA\sd*" -and
    $_ -notlike "*$env:LOCALAPPDATA\ktlint*" -and
    $_ -notlike "*$claudeBinDir*"
}) -join ";"
[Environment]::SetEnvironmentVariable("Path", $cleanedPath, "User")
Write-OK "PATH cleaned (removed sd/ktlint/claude entries)"

# --- Remove Claude Code ---

Write-Step "Removing Claude Code"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude /uninstall 2>&1 | Out-Null
    Write-OK "Claude Code uninstalled"
}
else { Write-Skip "Claude Code not found" }

# --- Remove Claude Code statusLine config (mirror of setup.ps1 / setup-wsl.sh) ---

Write-Step "Removing Claude Code statusLine config"

$claudeDir      = Join-Path $env:USERPROFILE ".claude"
$statusLinePath = Join-Path $claudeDir "statusline-command.sh"

# Windows statusline script
if (Test-Path $statusLinePath) {
    Remove-Item $statusLinePath -Force
    Write-OK "Windows statusline-command.sh removed"
}
else { Write-Skip "Windows statusline-command.sh not found" }

# Drop the statusLine key from settings.json, preserving any other keys
$settingsPath = Join-Path $claudeDir "settings.json"
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($settings -is [System.Management.Automation.PSCustomObject] -and $settings.PSObject.Properties['statusLine']) {
            $settings.PSObject.Properties.Remove('statusLine')
            $json = $settings | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
            Write-OK "statusLine key removed from Windows settings.json"
        }
        else { Write-Skip "no statusLine key in Windows settings.json" }
    }
    catch { Write-Host "    [WARN] Could not parse settings.json — left as-is" -ForegroundColor DarkYellow }
}
else { Write-Skip "Windows settings.json not found" }

# WSL side: unlink the symlink (restore the .bak if setup made one) and drop its statusLine key
$wslOk = $false
try {
    $r = (wsl -d Ubuntu-24.04 -- echo ok 2>$null) -replace "`0",""
    if (($r | Out-String).Trim() -eq "ok") { $wslOk = $true }
} catch {}

if ($wslOk) {
    wsl -d Ubuntu-24.04 -- bash -lc '
        L="$HOME/.claude/statusline-command.sh"
        if [ -L "$L" ]; then rm -f "$L"; fi
        if [ -f "$L.bak" ]; then mv "$L.bak" "$L"; fi
        S="$HOME/.claude/settings.json"
        if [ -f "$S" ] && command -v jq >/dev/null 2>&1; then
            T=$(mktemp)
            if jq "del(.statusLine)" "$S" > "$T" 2>/dev/null; then mv "$T" "$S"; else rm -f "$T"; fi
        fi
    ' 2>&1 | Out-Null
    Write-OK "WSL statusline symlink + settings.json statusLine cleaned"
}
else { Write-Skip "WSL Ubuntu-24.04 not ready — skipped WSL statusLine cleanup" }

# --- Remove fork/zoxide launchers + CLAUDE.md team defaults (Windows) ---
# Mirror of setup.ps1: strip the managed blocks it wrote into the PowerShell profiles and the
# user CLAUDE.md, and delete the Git Bash fork launcher. The marker-bounded strips preserve any
# content the user added outside the markers.

Write-Step "Removing fork/zoxide launchers and CLAUDE.md team defaults (Windows)"

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# PowerShell profiles (PS7 + 5.1): strip fork + zoxide blocks. Delete a profile only if it is
# empty afterwards (setup may have created it solely to hold these blocks).
$docs = [Environment]::GetFolderPath('MyDocuments')
$profilePaths = @(
    (Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
)
$managedPatterns = @(
    '# TADA-FORK-CLI:START[\s\S]*?# TADA-FORK-CLI:END',
    '# TADA-ZOXIDE-INIT:START[\s\S]*?# TADA-ZOXIDE-INIT:END'
)
foreach ($pf in $profilePaths) {
    $edition = Split-Path (Split-Path $pf -Parent) -Leaf
    if (-not (Test-Path $pf)) { Write-Skip "no $edition profile"; continue }
    $content = [System.IO.File]::ReadAllText($pf) -replace "`r`n", "`n"
    $cleaned = $content
    foreach ($pat in $managedPatterns) { $cleaned = [regex]::Replace($cleaned, $pat, "") }
    $cleaned = $cleaned.TrimEnd()
    if ($cleaned -ceq $content.TrimEnd()) {
        Write-Skip "no managed blocks in $edition profile"
    }
    elseif ($cleaned -eq "") {
        Remove-Item $pf -Force
        Write-OK "removed empty $edition profile (only held managed blocks)"
    }
    else {
        [System.IO.File]::WriteAllText($pf, "$cleaned`n", $utf8NoBom)
        Write-OK "stripped fork/zoxide blocks from $edition profile"
    }
}

# ~/.claude/CLAUDE.md: strip only the team-defaults block; always keep the rest.
$claudeMdPath = Join-Path $claudeDir "CLAUDE.md"
if (Test-Path $claudeMdPath) {
    $md = [System.IO.File]::ReadAllText($claudeMdPath) -replace "`r`n", "`n"
    $mdClean = ([regex]::Replace($md, '<!-- TADA-TEAM-DEFAULTS:START[\s\S]*?TADA-TEAM-DEFAULTS:END -->', "")).TrimEnd()
    if ($mdClean -ceq $md.TrimEnd()) {
        Write-Skip "no team-defaults block in CLAUDE.md"
    }
    else {
        [System.IO.File]::WriteAllText($claudeMdPath, "$mdClean`n", $utf8NoBom)
        Write-OK "team-defaults block removed from CLAUDE.md (your content kept)"
    }
}
else { Write-Skip "CLAUDE.md not found" }

# Git Bash fork launcher (~/bin/fork) written by setup.ps1
$gitBashFork = Join-Path $env:USERPROFILE "bin\fork"
if (Test-Path $gitBashFork) {
    Remove-Item $gitBashFork -Force
    Write-OK "removed Git Bash launcher $gitBashFork"
}
else { Write-Skip "Git Bash fork launcher not found" }

# --- Remove WSL fork/zoxide launchers + git delta config (mirror of setup-wsl.sh) ---
# Reuses $wslOk from the statusLine cleanup above. Drops ~/.fork.sh and its source lines from
# .bashrc/.zshrc, the zoxide init from .zshrc, and the delta pager keys from WSL's git config.

Write-Step "Removing WSL fork/zoxide launchers and git delta config"

if ($wslOk) {
    wsl -d Ubuntu-24.04 -- bash -lc '
rm -f "$HOME/.fork.sh"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    sed -i -e "/# Fork CLI launcher/d" -e "/\.fork\.sh/d" "$rc"
done
if [ -f "$HOME/.zshrc" ]; then
    sed -i -e "/# zoxide (smart cd, fasd replacement)/d" -e "/zoxide init zsh/d" "$HOME/.zshrc"
fi
if command -v git >/dev/null 2>&1; then
    for k in core.pager interactive.diffFilter delta.navigate delta.line-numbers alias.rawdiff; do
        git config --global --unset "$k" 2>/dev/null || true
    done
fi
' 2>&1 | Out-Null
    Write-OK "WSL ~/.fork.sh, zoxide init, and git delta config removed"
}
else { Write-Skip "WSL Ubuntu-24.04 not ready — skipped WSL launcher cleanup" }

# --- Remove environment variables (service ports) ---

Write-Step "Removing service port environment variables"

$portVars = @(
    "ACCOUNT_SERVER_PORT", "ACCOUNT_GRPC_PORT",
    "RIDE_GRPC_PORT", "RIDE_SERVER_PORT",
    "PAYMENT_GRPC_PORT", "PAYMENT_SERVER_PORT",
    "DISPATCH_GRPC_PORT", "DISPATCH_SERVER_PORT",
    "COUPON_GRPC_PORT", "COUPON_SERVER_PORT",
    "INBOX_GRPC_PORT", "INBOX_SERVER_PORT",
    "BALANCE_GRPC_PORT", "BALANCE_SERVER_PORT",
    "DELIVERY_GRPC_PORT", "DELIVERY_SERVER_PORT",
    "RATE_GRPC_PORT", "RATE_SERVER_PORT",
    "MOBILE_GRPC_PORT", "MOBILE_SERVER_PORT",
    "ROUTING_GRPC_PORT", "ROUTING_SERVER_PORT",
    "PENALTY_GRPC_PORT", "PENALTY_SERVER_PORT",
    "MEMBER_GRPC_PORT", "MEMBER_SERVER_PORT",
    "ADMIN_SERVER_PORT",
    "CORPORATE_GRPC_PORT", "CORPORATE_SERVER_PORT",
    "CHAT_GRPC_PORT", "CHAT_SERVER_PORT",
    "PLACE_GRPC_PORT", "PLACE_SERVER_PORT",
    "DRIVER_TUTORIAL_SERVER_PORT",
    "INCENTIVE_SERVER_PORT", "INCENTIVE_GRPC_PORT"
)

foreach ($var in $portVars) {
    $current = [Environment]::GetEnvironmentVariable($var, "User")
    if ($null -ne $current) {
        [Environment]::SetEnvironmentVariable($var, $null, "User")
        Write-OK "Removed $var"
    }
    else { Write-Skip "$var not set" }
}

# --- Remove GOOGLE_APPLICATION_CREDENTIALS ---

$gac = [Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", "User")
if ($null -ne $gac) {
    [Environment]::SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", $null, "User")
    Write-OK "Removed GOOGLE_APPLICATION_CREDENTIALS"
}
else { Write-Skip "GOOGLE_APPLICATION_CREDENTIALS not set" }

# --- Restore Windows settings to defaults ---

Write-Step "Restoring Windows Explorer and system settings"
$explorerAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$explorerCabinetState = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"

Set-ItemProperty -Path $explorerAdvanced -Name "HideFileExt" -Value 1
Set-ItemProperty -Path $explorerAdvanced -Name "Hidden" -Value 2
if (Test-Path $explorerCabinetState) {
    Set-ItemProperty -Path $explorerCabinetState -Name "FullPathAddress" -Value 0
}
Set-ItemProperty -Path $explorerAdvanced -Name "LaunchTo" -Value 2
Write-OK "Explorer settings restored to Windows defaults"

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 0 -ErrorAction SilentlyContinue
Write-OK "Developer Mode disabled"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 0 -ErrorAction SilentlyContinue
Write-OK "Long Paths disabled (Windows default)"

Set-ExecutionPolicy Restricted -Scope CurrentUser -Force -ErrorAction SilentlyContinue
Write-OK "ExecutionPolicy restored to Restricted"

# --- Remove keyboard remapping ---

Write-Step "Removing keyboard remapping"
$scancodeMap = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -ErrorAction SilentlyContinue
if ($scancodeMap) {
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -ErrorAction SilentlyContinue
    Write-OK "Caps Lock -> Korean/English removed (reboot to apply)"
}
else { Write-Skip "No Scancode Map found" }

$ptConfig = "$env:LOCALAPPDATA\Microsoft\PowerToys\Keyboard Manager\default.json"
if (Test-Path $ptConfig) {
    Remove-Item $ptConfig -Force
    Write-OK "PowerToys Ctrl/Alt swap removed"
}
else { Write-Skip "No PowerToys keyboard config found" }

# --- Restore Windows Terminal defaults (defaultProfile + Shift+Enter) ---
# setup.ps1 set defaultProfile to PowerShell 7 and added a Shift+Enter -> newline binding, but
# did NOT back up the original defaultProfile. So undo only our own changes: remove the
# Shift+Enter binding, and clear defaultProfile only when it still points at the pwsh7 profile
# (don't clobber a deliberate user choice). WT then falls back to its built-in default.

Write-Step "Restoring Windows Terminal settings"

# WT settings.json is JSONC; PS 5.1's ConvertFrom-Json chokes on comments/trailing commas.
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

$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $wtSettings)) {
    Write-Skip "Windows Terminal settings.json not found"
}
else {
    try {
        $json = ConvertFrom-Jsonc ([System.IO.File]::ReadAllText($wtSettings))
        $changed = $false

        # Clear defaultProfile only if it points at the PowerShell 7 (PowershellCore) profile.
        $profileList = if ($json.PSObject.Properties['profiles']) {
            if ($json.profiles -is [System.Management.Automation.PSCustomObject] -and $json.profiles.PSObject.Properties['list']) { $json.profiles.list }
            else { $json.profiles }
        } else { @() }
        $pwshProfile = @($profileList) | Where-Object {
            $null -ne $_ -and $_.PSObject.Properties['source'] -and $_.source -eq 'Windows.Terminal.PowershellCore'
        } | Select-Object -First 1
        $pwsh7Guid = if ($pwshProfile -and $pwshProfile.PSObject.Properties['guid']) { $pwshProfile.guid } else { '{574e775e-4f2a-5b96-ac1e-a2962a402336}' }
        if ($json.PSObject.Properties['defaultProfile'] -and $json.defaultProfile -eq $pwsh7Guid) {
            $json.PSObject.Properties.Remove('defaultProfile')
            $changed = $true
            Write-OK "defaultProfile cleared (was PowerShell 7 -> WT built-in default)"
        }
        else { Write-Skip "defaultProfile not pwsh7 - left as-is" }

        # Remove the Shift+Enter binding (inline {keys,command} form and the migrated form).
        $esc = [char]27
        $bindingRemoved = $false
        foreach ($k in @('actions','keybindings')) {
            if ($json.PSObject.Properties[$k]) {
                $orig = @($json.$k)
                $kept = @($orig | Where-Object {
                    $e = $_
                    if ($null -eq $e) { return $false }
                    $isKeys = $e.PSObject.Properties['keys'] -and $e.keys -eq 'shift+enter'
                    $isCmd  = $e.PSObject.Properties['command'] -and ($e.command -is [System.Management.Automation.PSCustomObject]) -and $e.command.PSObject.Properties['action'] -and $e.command.action -eq 'sendInput' -and $e.command.PSObject.Properties['input'] -and $e.command.input -eq ($esc + "`r")
                    -not ($isKeys -or $isCmd)
                })
                if ($kept.Count -ne $orig.Count) { $json.$k = $kept; $changed = $true; $bindingRemoved = $true }
            }
        }
        if ($bindingRemoved) { Write-OK "Shift+Enter -> newline binding removed" }

        if ($changed) {
            $out = $json | ConvertTo-Json -Depth 32
            [System.IO.File]::WriteAllText($wtSettings, $out, (New-Object System.Text.UTF8Encoding $false))
            Write-OK "Windows Terminal settings.json updated"
        }
        else { Write-Skip "No setup-added Windows Terminal changes found" }
    }
    catch { Write-Warn "Could not update Windows Terminal settings: $_" }
}

# --- Remove git config ---

Write-Step "Removing git global config"
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global --unset core.autocrlf 2>&1 | Out-Null
    git config --global --unset core.eol 2>&1 | Out-Null
    # delta pager config + rawdiff alias written by setup.ps1
    foreach ($k in @("core.pager", "interactive.diffFilter", "delta.navigate", "delta.line-numbers", "alias.rawdiff")) {
        git config --global --unset $k 2>&1 | Out-Null
    }
    Write-OK "git config (autocrlf, eol, delta pager + rawdiff alias) removed"
}
else { Write-Skip "git not installed" }

# --- Remove host.docker.internal from hosts file ---

Write-Step "Removing host.docker.internal from hosts file"
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
if ($hostsContent -match "host\.docker\.internal") {
    $newHosts = $hostsContent | Where-Object { $_ -notmatch "host\.docker\.internal" }
    Set-Content -Path $hostsFile -Value $newHosts -ErrorAction SilentlyContinue
    if ($?) {
        Write-OK "host.docker.internal removed from hosts file"
    }
    else {
        Write-Warn "Could not modify hosts file — remove manually"
    }
}
else { Write-Skip "host.docker.internal not in hosts file" }

# --- Remove RunOnce registry key (if pending) ---

Write-Step "Removing RunOnce registry key"
$runOncePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$removedAny = $false
foreach ($keyName in @("TadaSetupGuide", "TadaSetupResume")) {
    $val = Get-ItemProperty -Path $runOncePath -Name $keyName -ErrorAction SilentlyContinue
    if ($val) {
        Remove-ItemProperty -Path $runOncePath -Name $keyName
        $removedAny = $true
    }
}
if ($removedAny) { Write-OK "RunOnce keys removed" }
else { Write-Skip "No RunOnce keys found" }

# --- Remove .wslconfig ---

Write-Step "Removing .wslconfig"
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Remove-Item $wslConfigPath -Force
    Write-OK ".wslconfig removed"
}
else { Write-Skip ".wslconfig not found" }

# --- Remove ~/backend/ ---

Write-Step "Removing ~/backend/ (cloned repos)"
$backendDir = Join-Path $env:USERPROFILE "backend"
if (Test-Path $backendDir) {
    Remove-Item $backendDir -Recurse -Force
    Write-OK "$backendDir removed"
}
else { Write-Skip "$backendDir not found" }

# --- WSL (ask first) ---

Write-Step "WSL Ubuntu-24.04"
Write-Host "    Unregistering WSL Ubuntu-24.04 will DELETE all data inside it." -ForegroundColor Red
Write-Host "    (PostgreSQL, MongoDB, Redis, RabbitMQ, brew, all WSL files)" -ForegroundColor Red
Write-Host ""
$wslChoice = Read-Host "    Remove WSL Ubuntu-24.04? (y/N)"
if ($wslChoice -eq "y" -or $wslChoice -eq "Y") {
    wsl --unregister Ubuntu-24.04 2>&1 | Out-Null
    Write-OK "WSL Ubuntu-24.04 unregistered"
}
else {
    Write-Skip "WSL Ubuntu-24.04 kept"
}

# --- Done ---

Write-Step "Reset complete!"
Write-Host ""
Write-Host "  Your system has been cleaned. Run setup.ps1 again to start fresh." -ForegroundColor Green
Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR: Script failed at:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
}
} # end of & { wrapper
