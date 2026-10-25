[CmdletBinding()]
param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEvidence = Join-Path $taskRoot 'submission/lab6/evidence'
New-Item -ItemType Directory -Force -Path $taskEvidence | Out-Null
Push-Location $taskRoot
try {
    if (-not $SkipTests) {
        foreach ($taskProject in @('AuthService.Test','ProductService.Test','PricingService.Test','PolicyService.Test','PaymentService.Test','DashboardService.Test','PricingService.IntegrationTest')) {
            dotnet test "$taskProject/$taskProject.csproj" -c Release --no-build --no-restore --logger "trx;LogFileName=$taskProject.trx" --results-directory "$taskEvidence/tests" -- RunConfiguration.TreatNoTestsAsError=true
            if ($LASTEXITCODE -ne 0) { throw "Tests failed: $taskProject" }
            [xml]$taskTestResult = Get-Content -LiteralPath "$taskEvidence/tests/$taskProject.trx" -Raw
            if ([int]$taskTestResult.TestRun.ResultSummary.Counters.total -eq 0) { throw "No test cases executed: $taskProject. Check Windows Application Control diagnostics." }
        }
    }
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 60; $taskAttempt++) {
        try {
            $taskRegistry = Invoke-RestMethod 'http://localhost:8761/eureka/apps' -Headers @{Accept='application/json'}
            $taskNames = @($taskRegistry.applications.application | Where-Object { @($_.instance | Where-Object { $_.status -eq 'UP' }).Count -gt 0 } | ForEach-Object { $_.name })
            if ('PRODUCTSERVICE' -in $taskNames -and 'DASHBOARDSERVICE' -in $taskNames) { $taskReady = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $taskReady) { throw 'ProductService/DashboardService not UP in Eureka. Run start-lab6.ps1 first.' }
    dotnet run --project tools/Lab6.Verifier -c Release --no-build --no-restore -- "$taskEvidence/runtime-verification.json"
    if ($LASTEXITCODE -ne 0) { throw 'Runtime verification failed. See the evidence report and .runtime/lab6 logs.' }
} finally { Pop-Location }
