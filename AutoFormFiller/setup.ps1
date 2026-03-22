#!/usr/bin/env pwsh
# AutoFormFiller Setup Script for Windows
# This script automates the setup process

Write-Host "================================" -ForegroundColor Cyan
Write-Host "AutoFormFiller Setup Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Python installation
Write-Host "[1/5] Checking Python installation..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Python found: $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Python not found! Please install Python 3.8+ from python.org" -ForegroundColor Red
    exit 1
}

# Step 2: Create virtual environment (optional but recommended)
Write-Host ""
Write-Host "[2/5] Setting up Python environment..." -ForegroundColor Yellow
$venvPath = "backend\venv"
if (Test-Path $venvPath) {
    Write-Host "✓ Virtual environment already exists" -ForegroundColor Green
} else {
    Write-Host "Creating virtual environment..."
    python -m venv backend\venv
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Virtual environment created" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create virtual environment" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Activate venv and install dependencies
Write-Host ""
Write-Host "[3/5] Installing Python dependencies..." -ForegroundColor Yellow
& "backend\venv\Scripts\Activate.ps1"
pip install -r backend\requirements.txt
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Step 4: Setup environment variables
Write-Host ""
Write-Host "[4/5] Setting up environment variables..." -ForegroundColor Yellow
$envFile = "backend\.env"
if (Test-Path $envFile) {
    Write-Host "✓ .env file already exists" -ForegroundColor Green
    Write-Host "Make sure to add your ANTHROPIC_API_KEY to backend\.env" -ForegroundColor Cyan
} else {
    Copy-Item "backend\.env.example" $envFile
    Write-Host "✓ .env file created from template" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠ IMPORTANT: Edit backend\.env and add your API key:" -ForegroundColor Yellow
    Write-Host "  1. Go to https://console.anthropic.com/account/keys" -ForegroundColor White
    Write-Host "  2. Create or copy your API key" -ForegroundColor White
    Write-Host "  3. Replace 'your_api_key_here' in backend\.env" -ForegroundColor White
}

# Step 5: Check user_data.json
Write-Host ""
Write-Host "[5/5] Checking user data configuration..." -ForegroundColor Yellow
$userDataFile = "config\user_data.json"
if (Test-Path $userDataFile) {
    Write-Host "✓ user_data.json found" -ForegroundColor Green
    Write-Host "⚠ Make sure to edit config\user_data.json with your actual information" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Add your ANTHROPIC_API_KEY to backend\.env" -ForegroundColor White
Write-Host "2. Update config\user_data.json with your information" -ForegroundColor White
Write-Host "3. Start the backend server:" -ForegroundColor White
Write-Host "   cd backend" -ForegroundColor Gray
Write-Host "   .\venv\Scripts\Activate.ps1" -ForegroundColor Gray
Write-Host "   python app.py" -ForegroundColor Gray
Write-Host "4. Load the extension in Chrome/Edge:" -ForegroundColor White
Write-Host "   - Press Ctrl+Shift+M (or Cmd+Shift+M on Mac)" -ForegroundColor Gray
Write-Host "   - Click 'Load unpacked'" -ForegroundColor Gray
Write-Host "   - Select the 'extension' folder" -ForegroundColor Gray
Write-Host ""
