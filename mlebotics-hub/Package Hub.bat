@echo off
echo ============================================================
echo  MLEbotics Hub  --  Package + Deploy to Website
echo ============================================================
cd /d "%~dp0"

:: 1. Build exe
echo.
echo [1/3] Building with PyInstaller...
python -c "import PyInstaller" 2>nul || pip install pyinstaller
pyinstaller hub.spec --noconfirm
if %ERRORLEVEL% neq 0 (
    echo [FAILED] PyInstaller build failed. See above.
    pause & exit /b 1
)

:: 2. Zip the output folder
echo.
echo [2/3] Zipping dist\MLEbotics Hub\ ...
set ZIP_OUT=%~dp0mlebotics.com\website\downloads\mlebotics-hub.zip
if exist "%ZIP_OUT%" del "%ZIP_OUT%"
powershell -NoProfile -Command "Compress-Archive -Path 'dist\MLEbotics Hub\*' -DestinationPath '%ZIP_OUT%' -CompressionLevel Optimal"
if %ERRORLEVEL% neq 0 (
    echo [FAILED] Zipping failed.
    pause & exit /b 1
)
echo Saved: %ZIP_OUT%

:: 3. Deploy to S3 via deploy-website.ps1
echo.
echo [3/3] Deploying to S3...
cd /d "%~dp0mlebotics.com\website"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mlebotics.com\website\deploy-website.ps1"
if %ERRORLEVEL% neq 0 (
    echo [FAILED] Deployment failed. Check AWS credentials.
    pause & exit /b 1
)

echo.
echo ============================================================
echo  DONE!  mlebotics-hub.zip is now live on mlebotics.com
echo  Download link: https://mlebotics.com/downloads/mlebotics-hub.zip
echo ============================================================
pause
