param(
    [string]$Configuration = "Release"
)

$SolutionPath = "src\MySubscriptionService.sln"

Write-Host "🔧 Restoring dependencies..." -ForegroundColor Cyan
dotnet restore $SolutionPath

Write-Host "🔧 Building solution..." -ForegroundColor Cyan
dotnet build $SolutionPath --configuration $Configuration --no-restore

Write-Host "🔧 Building Docker image..." -ForegroundColor Cyan
docker build -t my-subscription-service:local .

Write-Host "✅ Build complete!" -ForegroundColor Green