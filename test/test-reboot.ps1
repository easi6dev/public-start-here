<#
    Reboot test script
    Tests: RunOnce browser open + admin PowerShell auto-launch
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/test/test-reboot.ps1 | iex
#>

& {
try {

Set-StrictMode -Version Latest

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator." -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "=== Reboot Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will:" -ForegroundColor White
Write-Host "  1. Register RunOnce: open browser (GitHub README)" -ForegroundColor Gray
Write-Host "  2. Register RunOnce: open admin PowerShell with test message" -ForegroundColor Gray
Write-Host "  3. Reboot" -ForegroundColor Gray
Write-Host ""
Write-Host "After reboot, verify:" -ForegroundColor Yellow
Write-Host "  - Browser opens https://github.com/easi6dev/public-start-here" -ForegroundColor Yellow
Write-Host "  - Admin PowerShell opens with green success message" -ForegroundColor Yellow
Write-Host ""

# Register RunOnce entries (same pattern as setup.ps1)
$testCmd = "Write-Host ''; Write-Host '=== REBOOT TEST PASSED ===' -ForegroundColor Green; Write-Host 'Admin PowerShell auto-launched successfully!' -ForegroundColor Green; Write-Host ''"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TadaSetupGuide" -Value "cmd /c start https://github.com/easi6dev/public-start-here"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TadaSetupResume" -Value "powershell -Command `"Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -Command $testCmd'`""

Write-Host "    [OK] RunOnce keys registered" -ForegroundColor Green
Write-Host ""

$rebootNow = Read-Host "    Reboot now? (Y/n)"
if ($rebootNow -ne "n" -and $rebootNow -ne "N") {
    Restart-Computer -Force
}
else {
    Write-Host ""
    Write-Host "    Reboot manually. RunOnce will trigger on next login." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    To clean up without rebooting:" -ForegroundColor Gray
    Write-Host "    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'TadaSetupGuide'" -ForegroundColor Gray
    Write-Host "    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'TadaSetupResume'" -ForegroundColor Gray
    Write-Host ""
}

} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
}
}
