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
Write-Host "  - git global config (autocrlf, eol)" -ForegroundColor White
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

# --- Remove git config ---

Write-Step "Removing git global config"
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global --unset core.autocrlf 2>&1 | Out-Null
    git config --global --unset core.eol 2>&1 | Out-Null
    Write-OK "git config (autocrlf, eol) removed"
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
