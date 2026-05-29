<#
    Test: Reset Mac keyboard remapping
    Removes PowerToys Ctrl/Alt swap + Scancode Map (Caps Lock -> 한/영)
    Run as Admin: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/test/test-keyboard-reset.ps1 | iex
#>

& {

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator." -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "=== Keyboard Remapping Reset ===" -ForegroundColor Cyan
Write-Host ""

# PowerToys config
$ptConfig = "$env:LOCALAPPDATA\Microsoft\PowerToys\Keyboard Manager\default.json"
if (Test-Path $ptConfig) {
    Remove-Item $ptConfig -Force
    Write-Host "[OK] PowerToys Ctrl/Alt swap removed" -ForegroundColor Green
}
else {
    Write-Host "[SKIP] No PowerToys keyboard config found" -ForegroundColor Yellow
}

# Scancode Map
$scancode = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -ErrorAction SilentlyContinue
if ($scancode) {
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map"
    Write-Host "[OK] Scancode Map removed (Caps Lock restored after reboot)" -ForegroundColor Green
}
else {
    Write-Host "[SKIP] No Scancode Map found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Restart PowerToys to apply Ctrl/Alt reset." -ForegroundColor White
Write-Host "Reboot to restore Caps Lock." -ForegroundColor White
Write-Host ""

}
