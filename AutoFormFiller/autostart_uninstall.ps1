# AutoFormFiller - Autostart Uninstaller
# Removes both server launchers from the Windows Startup folder

$Startup = [System.Environment]::GetFolderPath('Startup')

Write-Host ""
Write-Host "  Removing autostart entries..." -ForegroundColor Gray

$files = @(
    (Join-Path $Startup "AutoFormFiller-Backend.vbs"),
    (Join-Path $Startup "AutoFormFiller-PdfFiller.vbs")
)

foreach ($f in $files) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        Write-Host "  Removed: $(Split-Path $f -Leaf)" -ForegroundColor Green
    }
}

# Also kill any running instances
Stop-Process -Name pythonw -ErrorAction SilentlyContinue

Write-Host "  Done. Servers will no longer start at login." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
