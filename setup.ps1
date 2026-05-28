<#
    TADA Backend - Windows Setup Script (Phase 1 + Phase 2)
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1 | iex
#>

# Wrap in scriptblock + try/catch so errors don't kill the PowerShell session (irm | iex safe)
& {
try {

Set-StrictMode -Version Latest

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

Write-Host "`n  -- GUI Applications --" -ForegroundColor Magenta
foreach ($app in $guiApps) {
    Install-WingetPackage -Id $app.Id -Name $app.Name
}

Write-Host "`n  -- CLI Tools --" -ForegroundColor Magenta
foreach ($app in $cliApps) {
    Install-WingetPackage -Id $app.Id -Name $app.Name
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
    # Register RunOnce to auto-resume setup after reboot
    $setupUrl = "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1"
    $resumeCmd = "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -Command irm $setupUrl | iex'"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TadaSetupResume" -Value "powershell -WindowStyle Hidden -Command `"$resumeCmd`""

    Write-Host ""
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host "    Reboot required to continue setup" -ForegroundColor Cyan
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    WSL needs a reboot to finish installing." -ForegroundColor White
    Write-Host "    Don't worry - after reboot, this script will" -ForegroundColor White
    Write-Host "    automatically pick up where it left off and" -ForegroundColor White
    Write-Host "    install everything else for you:" -ForegroundColor White
    Write-Host ""
    Write-Host "      - WSL Ubuntu 24.04 services (DB, Redis, RabbitMQ...)" -ForegroundColor Gray
    Write-Host "      - CLI tools (gh, rg, fd, bat...)" -ForegroundColor Gray
    Write-Host "      - GitHub auth + backend repo clone" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    After reboot, a UAC prompt will pop up." -ForegroundColor Yellow
    Write-Host "    Just click 'Yes' and grab a coffee." -ForegroundColor Yellow
    Write-Host ""
    $rebootNow = Read-Host "    Reboot now? (Y/n)"
    if ($rebootNow -ne "n" -and $rebootNow -ne "N") {
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Warn "No worries! Reboot whenever you're ready."
        Write-Warn "The setup will resume automatically on your next login."
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
    Write-Warn "After rebooting, re-run this script to complete Phase 2 and 3."
}
else {
    $setupWslUrl = "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup-wsl.sh"
    $setupWslPath = "$env:TEMP\setup-wsl.sh"

    Write-Host "    Downloading setup-wsl.sh ..." -ForegroundColor White
    Invoke-WebRequest -Uri $setupWslUrl -OutFile $setupWslPath -UseBasicParsing

    Write-Host "    Running setup-wsl.sh inside WSL ..." -ForegroundColor White
    $wslScriptPath = (Clean-WslOutput (wsl -d Ubuntu-24.04 -- wslpath -u "$setupWslPath"))
    wsl -d Ubuntu-24.04 -- bash "$wslScriptPath"

    # --- Phase 3: GitHub Auth + Clone Backend Repos ---

    Write-Step "Phase 3: GitHub authentication and repository cloning"

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warn "GitHub CLI not found. Skipping Phase 3."
        Write-Host "    Install gh and run clone-repos.ps1 manually later." -ForegroundColor White
    }
    else {
        $authStatus = gh auth status 2>&1
        if ($authStatus -notmatch "Logged in") {
            Write-Host "    GitHub authentication required to clone backend repos." -ForegroundColor White
            Write-Host "    A browser window will open. Follow the instructions to authenticate." -ForegroundColor White
            Write-Host ""
            gh auth login --hostname github.com --git-protocol https --web
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "GitHub authentication was not completed. Skipping Phase 3."
            }
        }

        $authCheck = gh auth status 2>&1
        if ($authCheck -match "Logged in") {
            Write-OK "GitHub authenticated"

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
}

Write-Step "Setup complete!"
Write-Host ""
Write-Host "  Remaining manual steps:" -ForegroundColor Magenta
Write-Host "    1. Reboot if this was your first WSL install, then re-run this script" -ForegroundColor White
Write-Host "    2. Set credential environment variables (see reminders above)" -ForegroundColor White
Write-Host "    3. Enable Docker Desktop WSL integration with Ubuntu-24.04" -ForegroundColor White
Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR: Script failed at:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
}
} # end of & { wrapper
