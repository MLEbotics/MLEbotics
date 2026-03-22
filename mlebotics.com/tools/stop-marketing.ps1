try {
  $pids = (Get-NetTCPConnection -LocalPort 54321 -ErrorAction SilentlyContinue).OwningProcess | Select-Object -Unique
  if ($pids) {
    foreach ($pid in $pids) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue }
    Write-Host "Stopped process(es): $($pids -join ', ')"
  } else {
    Write-Host 'No process found listening on port 54321.'
  }
} catch {
  Write-Host "Error: $_"
}
