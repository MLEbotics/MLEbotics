# PDF Filler - Laptop Setup Script
# Run this once on any new machine to get everything working

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host ""
Write-Host "  PDF Filler - Setup" -ForegroundColor Cyan
Write-Host "  ==================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check Python ──────────────────────────────────────────────────────────
Write-Host "Checking Python..." -ForegroundColor Gray
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Host "ERROR: Python not found." -ForegroundColor Red
    Write-Host "Download it from https://python.org/downloads (check 'Add to PATH')" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
$pyVer = python --version 2>&1
Write-Host "  Found: $pyVer" -ForegroundColor Green

# ── 2. Create venv if missing ────────────────────────────────────────────────
$VenvPath = Join-Path $Root "backend\venv"
if (-not (Test-Path $VenvPath)) {
    Write-Host "Creating virtual environment..." -ForegroundColor Gray
    python -m venv $VenvPath
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Virtual environment already exists." -ForegroundColor Green
}

# ── 3. Install dependencies ─────────────────────────────────────────────────
Write-Host "Installing dependencies..." -ForegroundColor Gray
$pip = Join-Path $VenvPath "Scripts\pip.exe"
& $pip install -r (Join-Path $Root "backend\requirements.txt") --quiet
Write-Host "  Done." -ForegroundColor Green

# ── 4. Check/create .env ────────────────────────────────────────────────────
$EnvFile = Join-Path $Root "backend\.env"
if (-not (Test-Path $EnvFile)) {
    Write-Host ""
    Write-Host "  ANTHROPIC_API_KEY needed." -ForegroundColor Yellow
    Write-Host "  Get yours at: https://console.anthropic.com/account/keys" -ForegroundColor Cyan
    $key = Read-Host "  Paste your API key here"
    "ANTHROPIC_API_KEY=$key" | Set-Content $EnvFile
    Write-Host "  Saved to backend\.env" -ForegroundColor Green
} else {
    Write-Host "  API key already configured." -ForegroundColor Green
}

# ── 5. Check/copy user_data.json ────────────────────────────────────────────
$UserData = Join-Path $Root "config\user_data.json"
if (-not (Test-Path $UserData)) {
    New-Item -ItemType Directory -Path (Join-Path $Root "config") -Force | Out-Null
    @'
{
  "_comment": "Fill in your real details.",
  "name": "",
  "first_name": "",
  "last_name": "",
  "email": "",
  "phone": "",
  "address": "",
  "city": "",
  "state": "",
  "zip": "",
  "country": "",
  "company": "",
  "job_title": "",
  "website": "",
  "date_of_birth": "",
  "gender": ""
}
'@ | Set-Content $UserData
    Write-Host "  Created config\user_data.json — fill in your details via the extension's My Data tab." -ForegroundColor Yellow
} else {
    Write-Host "  user_data.json already exists." -ForegroundColor Green
}

# ── 6. Open firewall port ────────────────────────────────────────────────────
Write-Host "Opening firewall port 5001..." -ForegroundColor Gray
$existing = Get-NetFirewallRule -DisplayName "PDF Filler" -ErrorAction SilentlyContinue
if (-not $existing) {
    try {
        New-NetFirewallRule -DisplayName "PDF Filler" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow | Out-Null
        Write-Host "  Firewall rule added." -ForegroundColor Green
    } catch {
        Write-Host "  Could not add firewall rule (run as admin to enable LAN access)." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Firewall rule already exists." -ForegroundColor Green
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  To start PDF Filler, run:" -ForegroundColor Cyan
Write-Host "    cd pdf_filler" -ForegroundColor White
Write-Host "    .\start.ps1" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
