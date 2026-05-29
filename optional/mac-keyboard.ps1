<#
    Mac-style keyboard remapping
    - Ctrl <-> Alt swap via PowerToys Keyboard Manager
    - Caps Lock -> Korean/English toggle via registry Scancode Map
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/optional/mac-keyboard.ps1 | iex
#>

& {
try {

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator." -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "=== Mac-style Keyboard Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will change:" -ForegroundColor White
Write-Host "  Ctrl <-> Alt swap (PowerToys)" -ForegroundColor Yellow
Write-Host "    Left Alt  -> Left Ctrl  (thumb for shortcuts)" -ForegroundColor Gray
Write-Host "    Left Ctrl -> Left Alt" -ForegroundColor Gray
Write-Host "    Right Alt -> Right Ctrl" -ForegroundColor Gray
Write-Host "    Right Ctrl -> Right Alt" -ForegroundColor Gray
Write-Host ""
Write-Host "  Caps Lock -> Korean/English toggle (registry)" -ForegroundColor Yellow
Write-Host "    Tap Caps Lock to switch language" -ForegroundColor Gray
Write-Host "    Original Caps Lock function will be removed" -ForegroundColor Gray
Write-Host "    Requires reboot to take effect" -ForegroundColor Gray
Write-Host ""

# --- Ctrl <-> Alt (PowerToys) ---

$ptDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\Keyboard Manager"
if (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\PowerToys")) {
    Write-Host "ERROR: PowerToys is not installed. Run setup.ps1 first." -ForegroundColor Red
    return
}
if (-not (Test-Path $ptDir)) { New-Item -ItemType Directory -Path $ptDir -Force | Out-Null }

$config = @{
    remapKeys = @{
        inProcess = @(
            @{ originalKeys = "164"; newRemapKeys = "162" }
            @{ originalKeys = "162"; newRemapKeys = "164" }
            @{ originalKeys = "165"; newRemapKeys = "163" }
            @{ originalKeys = "163"; newRemapKeys = "165" }
        )
    }
    remapShortcuts = @{ global = @(); appSpecific = @() }
}
Set-Content -Path "$ptDir\default.json" -Value ($config | ConvertTo-Json -Depth 10) -Encoding UTF8
Write-Host "[OK] Ctrl <-> Alt swap configured" -ForegroundColor Green

# --- Caps Lock -> 한/영 (registry Scancode Map) ---

$scancodeMap = [byte[]](
    0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,
    0x72,0x00,0x3A,0x00,  # Caps Lock (0x003A) -> Hangul/English (0x0072)
    0x00,0x00,0x00,0x00
)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -Value $scancodeMap -Type Binary
Write-Host "[OK] Caps Lock -> Korean/English toggle configured" -ForegroundColor Green

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Restart PowerToys (system tray -> right-click -> Restart)" -ForegroundColor White
Write-Host "    2. Reboot to apply Caps Lock -> Korean/English" -ForegroundColor White
Write-Host ""
Write-Host "  To undo:" -ForegroundColor Gray
Write-Host "    Ctrl/Alt: PowerToys > Keyboard Manager > delete all" -ForegroundColor Gray
Write-Host "    Caps Lock: Run in admin PowerShell:" -ForegroundColor Gray
Write-Host "      Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' -Name 'Scancode Map'" -ForegroundColor Gray
Write-Host ""

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
}
