Start-Process -FilePath pnpm -ArgumentList 'dev:marketing' -WorkingDirectory 'D:\MLEbotics-Projects\mlebotics.com' -NoNewWindow
Start-Sleep -Seconds 2
Start-Process msedge 'http://localhost:54321/'
