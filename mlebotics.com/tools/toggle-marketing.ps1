try {
  $port = 54321
  $pids = (Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue).OwningProcess | Select-Object -Unique
  if ($pids) {
    foreach ($pid in $pids) {
      try { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue } catch {}
    }
    Write-Host "Stopped marketing server (port $port) - processes: $($pids -join ', ')"
    exit 0
  } else {
    Write-Host "Starting marketing dev server on port $port..."
    Start-Process -FilePath pnpm -ArgumentList 'dev:marketing' -WorkingDirectory 'D:\\MLEbotics-Projects\\mlebotics.com' -NoNewWindow
    Start-Sleep -Seconds 2
    Start-Process msedge "http://localhost:$port/"
    Write-Host "Marketing site launched at http://localhost:$port/"
    exit 0
  }
} catch {
  Write-Host "Error: $_"
  exit 1
}
