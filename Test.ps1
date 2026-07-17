param(
    [string]$Configuration = "Release"
)

$SolutionPath = "src\MySubscriptionService.sln"

Write-Host "🧪 Restoring..." -ForegroundColor Cyan
dotnet restore $SolutionPath

Write-Host "🧪 Running unit tests..." -ForegroundColor Cyan
dotnet test tests\MySubscriptionService.UnitTests\MySubscriptionService.UnitTests.csproj `
    --configuration $Configuration `
    --no-restore `
    --collect:"XPlat Code Coverage" `
    --results-directory "$PSScriptRoot\coverage\unit"

Write-Host "🧪 Running component tests..." -ForegroundColor Cyan
dotnet test tests\MySubscriptionService.ComponentTests\MySubscriptionService.ComponentTests.csproj `
    --configuration $Configuration `
    --no-restore `
    --collect:"XPlat Code Coverage" `
    --results-directory "$PSScriptRoot\coverage\component"

Write-Host "🧪 Running contract tests..." -ForegroundColor Cyan
dotnet test tests\MySubscriptionService.ContractTests\MySubscriptionService.ContractTests.csproj `
    --configuration $Configuration `
    --no-restore `
    --results-directory "$PSScriptRoot\coverage\contract"

Write-Host "🧪 Generating merged coverage report..." -ForegroundColor Cyan
dotnet tool install -g dotnet-reportgenerator-globaltool --quiet 2>$null
reportgenerator `
    -reports:"$PSScriptRoot\coverage\**\coverage.cobertura.xml" `
    -targetdir:"$PSScriptRoot\coverage-report" `
    -reporttypes:"Html"

Write-Host "✅ Tests complete! Open coverage-report\index.html to view." -ForegroundColor Green