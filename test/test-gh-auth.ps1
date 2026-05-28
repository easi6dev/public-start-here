<#
    gh auth test script
    Tests: GH_PROMPT_DISABLED + --skip-ssh-key + --web device flow
    Run: irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/test/test-gh-auth.ps1 | iex
#>

& {
try {

Write-Host ""
Write-Host "=== gh auth Test ===" -ForegroundColor Cyan
Write-Host ""

# Check gh exists
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: gh is not installed." -ForegroundColor Red
    return
}
Write-Host "[OK] gh found: $(gh --version | Select-Object -First 1)" -ForegroundColor Green

# Check current auth status
Write-Host ""
Write-Host "--- Current auth status ---" -ForegroundColor Yellow
$null = gh auth status 2>&1
$authCode = $LASTEXITCODE
Write-Host "Exit code: $authCode" -ForegroundColor White
if ($authCode -eq 0) {
    gh auth status
    Write-Host ""
    Write-Host "[OK] Already authenticated. Testing private repo access..." -ForegroundColor Green
    $null = gh api "repos/easi6dev/start-here" --jq ".name" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Private repo access works!" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] Authenticated but cannot access easi6dev/start-here" -ForegroundColor Red
    }
    return
}

# Not authenticated - test the login flow
Write-Host "[INFO] Not authenticated. Testing login flow..." -ForegroundColor Yellow
Write-Host ""
Write-Host "--- Running gh auth login (same as setup.ps1) ---" -ForegroundColor Yellow
Write-Host ""
Write-Host "A browser will open to GitHub." -ForegroundColor White
Write-Host "Enter the device code shown below and click Authorize." -ForegroundColor White
Write-Host ""

$env:GH_PROMPT_DISABLED = "1"
gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
$loginCode = $LASTEXITCODE
$env:GH_PROMPT_DISABLED = ""

Write-Host ""
if ($loginCode -eq 0) {
    Write-Host "[OK] gh auth login succeeded!" -ForegroundColor Green

    # Verify
    Write-Host ""
    Write-Host "--- Verifying auth ---" -ForegroundColor Yellow
    gh auth status

    Write-Host ""
    Write-Host "--- Testing private repo access ---" -ForegroundColor Yellow
    $null = gh api "repos/easi6dev/start-here" --jq ".name" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Private repo access works!" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] Auth succeeded but cannot access easi6dev/start-here" -ForegroundColor Red
        Write-Host "       Check your org membership." -ForegroundColor Red
    }
}
else {
    Write-Host "[FAIL] gh auth login failed (exit code: $loginCode)" -ForegroundColor Red
}

Write-Host ""

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
}
