#!/usr/bin/env pwsh
# AutoFormFiller Verification & Diagnostics Script
# Checks if everything is set up correctly

Write-Host "AutoFormFiller - System Verification" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$successes = @()

# 1. Check Python
Write-Host "[1/8] Checking Python..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -eq 0) {
    $successes += "Python found: $pythonVersion"
    Write-Host "✓ $pythonVersion" -ForegroundColor Green
} else {
    $errors += "Python not installed or not in PATH"
    Write-Host "✗ Python not found" -ForegroundColor Red
}

# 2. Check virtual environment
Write-Host "[2/8] Checking virtual environment..." -ForegroundColor Yellow
if (Test-Path "backend\venv\Scripts\Activate.ps1") {
    $successes += "Virtual environment found"
    Write-Host "✓ Virtual environment exists" -ForegroundColor Green
} else {
    $warnings += "Virtual environment not found (optional but recommended)"
    Write-Host "⚠ Virtual environment not found" -ForegroundColor Yellow
}

# 3. Check .env file
Write-Host "[3/8] Checking .env configuration..." -ForegroundColor Yellow
if (Test-Path "backend\.env") {
    $envContent = Get-Content "backend\.env"
    if ($envContent -match "ANTHROPIC_API_KEY=sk-") {
        $successes += ".env file configured with API key"
        Write-Host "✓ .env file found with API key" -ForegroundColor Green
    } elseif ($envContent -match "ANTHROPIC_API_KEY=your") {
        $errors += ".env file has placeholder API key (not configured)"
        Write-Host "✗ .env has placeholder key" -ForegroundColor Red
    } else {
        $warnings += ".env file exists but ANTHROPIC_API_KEY not properly set"
        Write-Host "⚠ .env might need configuration" -ForegroundColor Yellow
    }
} else {
    $errors += ".env file not found in backend directory"
    Write-Host "✗ .env file not found" -ForegroundColor Red
}

# 4. Check user_data.json
Write-Host "[4/8] Checking user_data.json..." -ForegroundColor Yellow
if (Test-Path "config\user_data.json") {
    try {
        $userData = Get-Content "config\user_data.json" | ConvertFrom-Json
        $successes += "user_data.json is valid JSON"
        Write-Host "✓ user_data.json is valid" -ForegroundColor Green
        Write-Host "  Fields: $($userData | Get-Member -MemberType NoteProperty | Measure-Object).Count" -ForegroundColor Gray
    } catch {
        $errors += "user_data.json exists but contains invalid JSON"
        Write-Host "✗ user_data.json is invalid JSON" -ForegroundColor Red
    }
} else {
    $errors += "user_data.json not found"
    Write-Host "✗ user_data.json not found" -ForegroundColor Red
}

# 5. Check requirements.txt
Write-Host "[5/8] Checking dependencies..." -ForegroundColor Yellow
if (Test-Path "backend\requirements.txt") {
    $successes += "requirements.txt found"
    Write-Host "✓ requirements.txt found" -ForegroundColor Green
} else {
    $errors += "requirements.txt not found"
    Write-Host "✗ requirements.txt not found" -ForegroundColor Red
}

# 6. Check extension files
Write-Host "[6/8] Checking extension files..." -ForegroundColor Yellow
$extensionFiles = @("manifest.json", "popup.html", "popup.js", "content.js", "background.js")
$missingFiles = @()
foreach ($file in $extensionFiles) {
    if (-not (Test-Path "extension\$file")) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    $successes += "All extension files present"
    Write-Host "✓ All extension files present" -ForegroundColor Green
} else {
    $errors += "Missing extension files: $($missingFiles -join ', ')"
    Write-Host "✗ Missing files: $($missingFiles -join ', ')" -ForegroundColor Red
}

# 7. Check manifest.json validity
Write-Host "[7/8] Checking manifest.json..." -ForegroundColor Yellow
if (Test-Path "extension\manifest.json") {
    try {
        $manifest = Get-Content "extension\manifest.json" | ConvertFrom-Json
        if ($manifest.manifest_version -eq 3) {
            $successes += "manifest.json is valid MV3 format"
            Write-Host "✓ manifest.json is valid Manifest V3" -ForegroundColor Green
        } else {
            $warnings += "manifest.json uses version $($manifest.manifest_version), expected 3"
            Write-Host "⚠ manifest.json version is $($manifest.manifest_version)" -ForegroundColor Yellow
        }
    } catch {
        $errors += "manifest.json contains invalid JSON"
        Write-Host "✗ manifest.json is invalid JSON" -ForegroundColor Red
    }
} else {
    $errors += "manifest.json not found"
    Write-Host "✗ manifest.json not found" -ForegroundColor Red
}

# 8. Check if port 5000 is available
Write-Host "[8/8] Checking port availability..." -ForegroundColor Yellow
try {
    $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port 5000 -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        $warnings += "Port 5000 is already in use (Flask server might be running)"
        Write-Host "⚠ Port 5000 is in use" -ForegroundColor Yellow
    } else {
        $successes += "Port 5000 is available"
        Write-Host "✓ Port 5000 is available" -ForegroundColor Green
    }
} catch {
    $successes += "Port 5000 check completed"
    Write-Host "✓ Port check completed" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "===== SUMMARY =====" -ForegroundColor Cyan

if ($successes.Count -gt 0) {
    Write-Host ""
    Write-Host "Successes ($($successes.Count)):" -ForegroundColor Green
    foreach ($success in $successes) {
        Write-Host "  ✓ $success" -ForegroundColor Green
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  ⚠ $warning" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors ($($errors.Count)):" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  ✗ $error" -ForegroundColor Red
    }
}

Write-Host ""
if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✓ All checks passed! Ready to use." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Activate Python environment: .\backend\venv\Scripts\Activate.ps1" -ForegroundColor Gray
    Write-Host "2. Start the backend: python app.py" -ForegroundColor Gray
    Write-Host "3. Load extension in Chrome/Edge (Ctrl+Shift+M, Load unpacked)" -ForegroundColor Gray
} elseif ($errors.Count -eq 0) {
    Write-Host "⚠ Some warnings found, but you can proceed with caution." -ForegroundColor Yellow
} else {
    Write-Host "✗ Fix the errors above before proceeding." -ForegroundColor Red
    Write-Host ""
    Write-Host "See TROUBLESHOOTING.md for help." -ForegroundColor Cyan
}

Write-Host ""
