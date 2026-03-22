$desktop = [Environment]::GetFolderPath('Desktop')

$ws = New-Object -ComObject WScript.Shell

$togglePath = Join-Path $desktop 'Toggle Marketing.lnk'
$u = $ws.CreateShortcut($togglePath)
$u.TargetPath = 'powershell.exe'
$u.Arguments = "-ExecutionPolicy Bypass -File 'D:\\MLEbotics-Projects\\mlebotics.com\\tools\\toggle-marketing.ps1'"
$u.WorkingDirectory = 'D:\\MLEbotics-Projects\\mlebotics.com'
$u.Save()

Write-Host "Shortcut created on desktop: Toggle Marketing.lnk"
