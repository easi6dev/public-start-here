<#
    Test: Mac keyboard remapping detection
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/test/test-keyboard-check.ps1 | iex
#>

& {

Write-Host ""
Write-Host "=== Keyboard Remapping Detection Test ===" -ForegroundColor Cyan
Write-Host ""

# Check PowerToys config
$ptConfigPath = "$env:LOCALAPPDATA\Microsoft\PowerToys\Keyboard Manager\default.json"
Write-Host "PowerToys config path: $ptConfigPath" -ForegroundColor Gray
$ptConfigExists = Test-Path $ptConfigPath
Write-Host "  Exists: $ptConfigExists" -ForegroundColor $(if ($ptConfigExists) { "Green" } else { "Red" })
if ($ptConfigExists) {
    Write-Host "  Content:" -ForegroundColor Gray
    Get-Content $ptConfigPath | Write-Host -ForegroundColor DarkGray
}

Write-Host ""

# Check Scancode Map
$scancodeReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -ErrorAction SilentlyContinue
$scancodeExists = $null -ne $scancodeReg
Write-Host "Scancode Map registry:" -ForegroundColor Gray
Write-Host "  Path: HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -ForegroundColor Gray
Write-Host "  Exists: $scancodeExists" -ForegroundColor $(if ($scancodeExists) { "Green" } else { "Red" })
if ($scancodeExists) {
    Write-Host "  Value: $($scancodeReg.'Scancode Map' -join ',')" -ForegroundColor DarkGray
}

Write-Host ""

# Simulate the check from setup.ps1
Write-Host "--- Simulating setup.ps1 check ---" -ForegroundColor Yellow
if ($ptConfigExists -and $scancodeExists) {
    Write-Host "  Result: SKIP (both exist, would not ask)" -ForegroundColor Green
}
elseif ($ptConfigExists) {
    Write-Host "  Result: WOULD ASK (PowerToys exists but Scancode Map missing)" -ForegroundColor Yellow
}
elseif ($scancodeExists) {
    Write-Host "  Result: WOULD ASK (Scancode Map exists but PowerToys config missing)" -ForegroundColor Yellow
}
else {
    Write-Host "  Result: WOULD ASK (neither exists)" -ForegroundColor Yellow
}

Write-Host ""

}
