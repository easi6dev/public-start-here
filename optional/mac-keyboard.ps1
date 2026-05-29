<#
    Mac-style keyboard remapping via PowerToys Keyboard Manager
    Swaps Ctrl <-> Alt so you can use your thumb for shortcuts (like Command on Mac)
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/optional/mac-keyboard.ps1 | iex
#>

& {
try {

Write-Host ""
Write-Host "=== Mac-style Keyboard Setup (PowerToys) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will remap:" -ForegroundColor White
Write-Host "  Left Alt  -> Left Ctrl   (thumb for shortcuts)" -ForegroundColor Gray
Write-Host "  Left Ctrl -> Left Alt" -ForegroundColor Gray
Write-Host "  Right Alt -> Right Ctrl" -ForegroundColor Gray
Write-Host "  Right Ctrl -> Right Alt" -ForegroundColor Gray
Write-Host "  Caps Lock -> IME toggle  (tap to switch Korean/English)" -ForegroundColor Gray
Write-Host "  Left Alt + Space -> IME toggle" -ForegroundColor Gray
Write-Host ""

$ptDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\Keyboard Manager"

if (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\PowerToys")) {
    Write-Host "ERROR: PowerToys is not installed. Run setup.ps1 first." -ForegroundColor Red
    return
}

if (-not (Test-Path $ptDir)) {
    New-Item -ItemType Directory -Path $ptDir -Force | Out-Null
}

$config = @{
    remapKeys = @{
        inProcess = @(
            @{ originalKeys = "164"; newRemapKeys = "162" }  # Left Alt (0xA4) -> Left Ctrl (0xA2)
            @{ originalKeys = "162"; newRemapKeys = "164" }  # Left Ctrl (0xA2) -> Left Alt (0xA4)
            @{ originalKeys = "165"; newRemapKeys = "163" }  # Right Alt (0xA5) -> Right Ctrl (0xA3)
            @{ originalKeys = "163"; newRemapKeys = "165" }  # Right Ctrl (0xA3) -> Right Alt (0xA5)
            @{ originalKeys = "20"; newRemapKeys = "21" }    # Caps Lock (0x14) -> VK_HANGUL (0x15, 한/영)
        )
    }
    remapShortcuts = @{
        global = @(
            @{ originalKeys = "164;32"; newRemapKeys = "21" }  # Left Alt + Space -> VK_HANGUL (한/영)
        )
        appSpecific = @()
    }
}

$configJson = $config | ConvertTo-Json -Depth 10
Set-Content -Path "$ptDir\default.json" -Value $configJson -Encoding UTF8

Write-Host "[OK] Keyboard remapping configured!" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart PowerToys to apply:" -ForegroundColor Yellow
Write-Host "  1. Right-click PowerToys in system tray -> Restart" -ForegroundColor White
Write-Host "  2. Or: Settings > Keyboard Manager > verify the remappings" -ForegroundColor White
Write-Host ""
Write-Host "  To undo: open PowerToys > Keyboard Manager > delete all remappings" -ForegroundColor Gray
Write-Host ""

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
}
