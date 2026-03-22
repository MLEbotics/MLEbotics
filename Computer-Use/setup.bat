@echo off
echo ============================================================
echo   Computer Use - Setup
echo ============================================================

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found!
    echo Please install Python from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during install.
    pause
    exit /b 1
)

echo [OK] Python found.

:: Create virtual environment
if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
)

:: Activate and install deps
echo Installing dependencies...
call .venv\Scripts\activate.bat
:: Clear SSLKEYLOGFILE to prevent pip from crashing on protected virtual paths
set SSLKEYLOGFILE=
pip install -r requirements.txt --quiet

:: Create .env from example if not already present
if not exist ".env" (
    copy .env.example .env >nul
    echo.
    echo [ACTION NEEDED] Open the .env file and paste your Anthropic API key:
    echo   ANTHROPIC_API_KEY=your_api_key_here
    echo.
    echo Get a free API key at: https://console.anthropic.com/
    notepad .env
)

echo.
echo ============================================================
echo   Setup complete! To run:
echo     1. Double-click run.bat
echo     OR
echo     1. Open a terminal in this folder
echo     2. Run: .venv\Scripts\activate
echo     3. Run: python main.py
echo ============================================================
pause
