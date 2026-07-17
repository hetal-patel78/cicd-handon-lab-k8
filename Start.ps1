Write-Host "🚀 Building Docker image..." -ForegroundColor Cyan
docker build -t my-subscription-service:local .

Write-Host "🚀 Starting container (port 5210)..." -ForegroundColor Cyan
docker run -d --name my-subscription-service -p 5210:5210 my-subscription-service:local

Write-Host "✅ Service running at http://localhost:5210" -ForegroundColor Green
Write-Host "   Try: curl http://localhost:5210/api/subscriptions" -ForegroundColor Yellow
Write-Host "   Health: curl http://localhost:5210/ping" -ForegroundColor Yellow