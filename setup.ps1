<#
    TADA Backend - Windows Setup Script (Phase 1 + Phase 2)
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Admin check (works with irm | iex, unlike #Requires) ---

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then retry." -ForegroundColor Yellow
    exit 1
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

function Set-EnvIfMissing {
    param(
        [string]$Name,
        [string]$Value
    )
    $current = [Environment]::GetEnvironmentVariable($Name, "User")
    if ($null -eq $current) {
        [Environment]::SetEnvironmentVariable($Name, $Value, "User")
        Write-OK "$Name = $Value"
    }
    else {
        Write-Skip "$Name already set ($current)"
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
    @{ Id = "Notion.Notion";                    Name = "Notion" },
    @{ Id = "MongoDB.Compass.Full";              Name = "MongoDB Compass" },
    @{ Id = "Google.AndroidStudio";              Name = "Android Studio" }
)

$cliApps = @(
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
    & ([scriptblock]::Create((Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -UseBasicParsing).Content))
    Write-OK "Claude Code installed"
}

# --- Git Config ---

Write-Step "Configuring git defaults"
git config --global core.autocrlf input
git config --global core.eol lf
Write-OK "core.autocrlf=input, core.eol=lf"

# --- Environment Variables (Service Ports) ---

Write-Step "Setting service port environment variables"

$ports = @{
    ACCOUNT_SERVER_PORT          = "18000"
    ACCOUNT_GRPC_PORT            = "16000"
    RIDE_GRPC_PORT               = "16001"
    RIDE_SERVER_PORT             = "18001"
    PAYMENT_GRPC_PORT            = "16002"
    PAYMENT_SERVER_PORT          = "18002"
    DISPATCH_GRPC_PORT           = "16003"
    DISPATCH_SERVER_PORT         = "18003"
    COUPON_GRPC_PORT             = "16004"
    COUPON_SERVER_PORT           = "18004"
    INBOX_GRPC_PORT              = "16006"
    INBOX_SERVER_PORT            = "18006"
    BALANCE_GRPC_PORT            = "16007"
    BALANCE_SERVER_PORT          = "18007"
    DELIVERY_GRPC_PORT           = "16010"
    DELIVERY_SERVER_PORT         = "18010"
    RATE_GRPC_PORT               = "16011"
    RATE_SERVER_PORT             = "18011"
    MOBILE_GRPC_PORT             = "16012"
    MOBILE_SERVER_PORT           = "18012"
    ROUTING_GRPC_PORT            = "16013"
    ROUTING_SERVER_PORT          = "18013"
    PENALTY_GRPC_PORT            = "16014"
    PENALTY_SERVER_PORT          = "18014"
    MEMBER_GRPC_PORT             = "16016"
    MEMBER_SERVER_PORT           = "18016"
    ADMIN_SERVER_PORT            = "18020"
    CORPORATE_GRPC_PORT          = "16023"
    CORPORATE_SERVER_PORT        = "18023"
    CHAT_GRPC_PORT               = "16024"
    CHAT_SERVER_PORT             = "18024"
    PLACE_GRPC_PORT              = "16026"
    PLACE_SERVER_PORT            = "18026"
    DRIVER_TUTORIAL_SERVER_PORT  = "18018"
    INCENTIVE_SERVER_PORT        = "18033"
    INCENTIVE_GRPC_PORT          = "16033"
}

foreach ($entry in $ports.GetEnumerator()) {
    Set-EnvIfMissing -Name $entry.Key -Value $entry.Value
}

# --- Credential reminders ---

Write-Step "Manual setup reminders"
Write-Warn "Set these environment variables manually:"
Write-Host "    - GITHUB_USERNAME" -ForegroundColor White
Write-Host "    - GITHUB_TOKEN" -ForegroundColor White
Write-Host "    - AWS_ACCESS_KEY" -ForegroundColor White
Write-Host "    - aws_secret_access_key" -ForegroundColor White
Write-Host "    - GOOGLE_APPLICATION_CREDENTIALS" -ForegroundColor White
Write-Host ""
Write-Warn "After setting credentials, run: aws configure"
Write-Warn "Docker Desktop: Enable WSL integration with Ubuntu-24.04 in Settings > Resources > WSL Integration"

# --- WSL 2 + Ubuntu 24.04 ---

Write-Step "Installing WSL 2 with Ubuntu 24.04"

$wslInstalled = Clean-WslOutput (wsl --list --quiet 2>&1)
if ($wslInstalled -match "Ubuntu.?24\.04") {
    Write-Skip "Ubuntu 24.04 already installed on WSL"
}
else {
    Write-Host "    Installing WSL and Ubuntu 24.04 ..." -ForegroundColor White
    wsl --install -d Ubuntu-24.04 --no-launch
    Write-OK "Ubuntu-24.04 queued for install"
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
