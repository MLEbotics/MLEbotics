# dev-restart.ps1 — restart one or all MLEbotics dev servers
$root = "D:\MLEbotics\mlebotics.com"

$apps = @(
    @{ num=1; title="Marketing"; cmd="pnpm run dev:marketing"; port=54321 },
    @{ num=2; title="Console";   cmd="pnpm run dev:console";   port=3001  },
    @{ num=3; title="Studio";    cmd="pnpm run dev:studio";    port=3002  },
    @{ num=4; title="Docs";      cmd="pnpm run dev:docs";      port=3003  }
)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  MLEbotics — Restart Dev Server" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
foreach ($app in $apps) {
    Write-Host "  [$($app.num)] $($app.title)" -ForegroundColor Cyan
}
Write-Host "  [A] All servers" -ForegroundColor Green
Write-Host ""

$choice = Read-Host "Enter choice"

function Find-FreePort($startPort) {
    $port = $startPort
    while (Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue) {
        $port++
    }
    return $port
}

function Start-Server($app) {
    $port = Find-FreePort $app.port
    $cmd  = $app.cmd

    if ($port -ne $app.port) {
        Write-Host "  [~] Port $($app.port) busy, using $port instead" -ForegroundColor DarkYellow
        # Inject the new port into the turbo command
        if ($cmd -match '--port \d+') {
            $cmd = $cmd -replace '--port \d+', "--port $port"
        } else {
            $cmd = "$cmd -- --port $port"
        }
    }

    Write-Host "  [+] Launching $($app.title) on port $port..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit",
        "-File", "`"$root\dev-server.ps1`"",
        "-Title", "`"$($app.title)`"",
        "-Cmd", "`"$cmd`""
    )
}

if ($choice -match '^[Aa]$') {
    foreach ($app in $apps) {
        Start-Server $app
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""
    Write-Host "All servers restarted." -ForegroundColor Green
} else {
    $num = [int]$choice
    $selected = $apps | Where-Object { $_.num -eq $num }
    if ($selected) {
        Start-Server $selected
        Write-Host ""
        Write-Host "$($selected.title) restarted." -ForegroundColor Green
    } else {
        Write-Host "Invalid choice." -ForegroundColor Red
    }
}

Start-Sleep 2
