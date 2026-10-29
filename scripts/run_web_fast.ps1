param(
  [int]$Port = 8080
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ClassRealm Web Fast-Boot Launcher (Intel Celeron Optimized)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Running in --profile mode (Single compiled bundle, skips 1000 DDC debug modules)" -ForegroundColor Yellow
Write-Host "Opening http://localhost:$Port ..." -ForegroundColor Gray

flutter run -d chrome --profile --web-port=$Port

