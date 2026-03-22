# PDF Filler - Standalone App Launcher
# Runs at http://localhost:5001

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python    = Join-Path $ScriptDir ".." "backend" "venv" "Scripts" "python.exe"
$App       = Join-Path $ScriptDir "pdf_filler.py"

if (-not (Test-Path $Python)) {
    Write-Host "ERROR: Virtual environment not found at $Python" -ForegroundColor Red
    Write-Host "Please run setup.ps1 first from the root folder." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  ========================================" -ForegroundColor DarkYellow
Write-Host "   PDF Filler" -ForegroundColor Yellow
Write-Host "   http://localhost:5001" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  Opening browser..." -ForegroundColor Gray
Start-Sleep -Seconds 1
Start-Process "http://localhost:5001"

& $Python $App
