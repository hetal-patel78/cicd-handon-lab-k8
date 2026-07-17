Write-Host "🛑 Stopping container..." -ForegroundColor Cyan
docker stop my-subscription-service 2>$null
docker rm my-subscription-service 2>$null

Write-Host "✅ Container stopped and removed." -ForegroundColor Green