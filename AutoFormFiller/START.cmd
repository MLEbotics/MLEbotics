@echo off
REM AutoFormFiller Quick Start Batch Script for Windows
REM This is an alternative to the PowerShell script for users without PowerShell

setlocal enabledelayedexpansion

echo.
echo ===============================================
echo   AutoFormFiller - Quick Start
echo ===============================================
echo.

REM Check Python
echo Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found! Please install Python 3.8+ from python.org
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set "pythonver=%%i"
    echo OK: Found !pythonver!
)

echo.
echo Creating virtual environment...
if exist backend\venv (
    echo Virtual environment already exists
) else (
    python -m venv backend\venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    ) else (
        echo Virtual environment created
    )
)

echo.
echo Activating virtual environment and installing dependencies...
call backend\venv\Scripts\activate.bat
pip install -q -r backend\requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
) else (
    echo Dependencies installed
)

echo.
echo Checking configuration files...
if not exist backend\.env (
    echo Creating .env from template...
    copy backend\.env.example backend\.env
    echo.
    echo *** IMPORTANT ***
    echo Please edit backend\.env and add your ANTHROPIC_API_KEY
    echo Get your API key from: https://console.anthropic.com/account/keys
    echo.
    pause
)

if not exist config\user_data.json (
    echo ERROR: config\user_data.json not found
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   Setup Complete!
echo ===============================================
echo.
echo To start the backend server:
echo   1. cd backend
echo   2. venv\Scripts\activate
echo   3. python app.py
echo.
echo To load the extension:
echo   1. Press Ctrl+Shift+M in Chrome/Edge/Brave
echo   2. Enable Developer Mode (top right)
echo   3. Click "Load unpacked"
echo   4. Select the "extension" folder
echo.
pause
