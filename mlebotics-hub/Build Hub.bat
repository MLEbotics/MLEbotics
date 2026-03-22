@echo off
echo ============================================================
echo  MLEbotics Hub  --  PyInstaller build
echo ============================================================

cd /d "%~dp0"

:: Install PyInstaller if missing
python -c "import PyInstaller" 2>nul || (
    echo Installing PyInstaller...
    pip install pyinstaller
)

:: Build
echo.
echo Building...
pyinstaller hub.spec --noconfirm

if %ERRORLEVEL% neq 0 (
    echo.
    echo [FAILED] Build exited with an error. See output above.
    pause
    exit /b 1
)

echo.
echo [DONE] Executable is in:  dist\MLEbotics Hub\MLEbotics Hub.exe
echo.
pause
