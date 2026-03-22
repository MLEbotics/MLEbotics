# AutoFormFiller - Autostart Installer
# Adds silent launchers to the Windows Startup folder (no admin needed)

$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonW   = Join-Path $Root "backend\venv\Scripts\pythonw.exe"  # no console window
$Backend   = Join-Path $Root "backend\app.py"
$PdfFiller = Join-Path $Root "pdf_filler\pdf_filler.py"
$Startup   = [System.Environment]::GetFolderPath('Startup')  # C:\Users\<you>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

if (-not (Test-Path $PythonW)) {
    Write-Host "ERROR: Virtual environment not found. Run setup_laptop.ps1 first." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  AutoFormFiller - Autostart Setup" -ForegroundColor Cyan
Write-Host "  ==================================" -ForegroundColor Cyan
Write-Host ""

# Create a tiny VBScript for each server — VBScript is needed to hide the console window
function Write-SilentLauncher {
    param($Name, $ScriptPath, $WorkingDir)
    $vbs = @"
Set objShell = CreateObject("WScript.Shell")
objShell.CurrentDirectory = "$WorkingDir"
objShell.Run """$PythonW"" ""$ScriptPath""", 0, False
"@
    $vbsPath = Join-Path $Startup "$Name.vbs"
    Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII
    Write-Host "  Added to Startup: $Name" -ForegroundColor Green
    return $vbsPath
}

$vbs1 = Write-SilentLauncher -Name "AutoFormFiller-Backend"   -ScriptPath $Backend   -WorkingDir (Join-Path $Root "backend")
$vbs2 = Write-SilentLauncher -Name "AutoFormFiller-PdfFiller" -ScriptPath $PdfFiller -WorkingDir (Join-Path $Root "pdf_filler")

# Start them right now without rebooting
Write-Host ""
Write-Host "  Starting servers now..." -ForegroundColor Gray
Start-Process "wscript.exe" -ArgumentList "`"$vbs1`""
Start-Sleep -Seconds 3
Start-Process "wscript.exe" -ArgumentList "`"$vbs2`""
Start-Sleep -Seconds 3

# Verify
$b = Invoke-WebRequest -Uri http://localhost:5000/health -UseBasicParsing -ErrorAction SilentlyContinue
$p = Invoke-WebRequest -Uri http://localhost:5001/health -UseBasicParsing -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  Backend    (port 5000): $(if ($b) { 'Running ✔' } else { 'Starting up — wait a few seconds' })" -ForegroundColor $(if ($b) { 'Green' } else { 'Yellow' })
Write-Host "  PDF Filler (port 5001): $(if ($p) { 'Running ✔' } else { 'Starting up — wait a few seconds' })" -ForegroundColor $(if ($p) { 'Green' } else { 'Yellow' })
Write-Host ""
Write-Host "  Both servers will now start automatically every time you log in." -ForegroundColor Cyan
Write-Host "  Startup folder: $Startup" -ForegroundColor Gray
Write-Host "  To uninstall autostart, run: .\autostart_uninstall.ps1" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
