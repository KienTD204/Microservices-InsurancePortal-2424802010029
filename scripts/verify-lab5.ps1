[CmdletBinding()]
param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEvidence = Join-Path $taskRoot 'submission/lab5/evidence'
New-Item -ItemType Directory -Force -Path $taskEvidence | Out-Null
Push-Location $taskRoot
try {
    if (-not $SkipTests) {
        foreach ($taskProject in @('PricingService.Test', 'PricingService.IntegrationTest')) {
            dotnet test "$taskProject/$taskProject.csproj" -c Release --logger trx --results-directory "$taskEvidence/tests"
            if ($LASTEXITCODE -ne 0) { throw "Tests failed: $taskProject" }
        }
    }
    $taskHealth = Invoke-RestMethod 'http://localhost:5041/health'
    if ($taskHealth.status -ne 'UP') { throw 'Health endpoint did not report UP.' }
    $taskRegistry = Invoke-RestMethod 'http://localhost:8761/eureka/apps/PRICINGSERVICE' -Headers @{Accept='application/json'}
    $taskInstances = @($taskRegistry.application.instance)
    $taskInstance = @($taskInstances | Where-Object { $_.status -eq 'UP' -and $_.port.'$' -eq 5041 })
    if ($taskInstance.Count -ne 1) { throw 'Expected exactly one UP PricingService instance on port 5041.' }
    $taskRequest = @{
        productCode = 'TRI'
        policyFrom = '2026-10-23T00:00:00+07:00'
        policyTo = '2026-10-28T00:00:00+07:00'
        selectedCovers = @('C1','C2','C3')
        answers = @(
            @{questionCode='NUM_OF_ADULTS';questionType=1;answer=1},
            @{questionCode='NUM_OF_CHILDREN';questionType=1;answer=1},
            @{questionCode='DESTINATION';questionType=0;answer='EUR'}
        )
    }
    $taskPrice = Invoke-RestMethod 'http://localhost:5041/api/Pricing' -Method Post -ContentType 'application/json' -Body ($taskRequest | ConvertTo-Json -Depth 10)
    if ($taskPrice.totalPrice -ne 98 -or $taskPrice.coverPrices.C1 -ne 26 -or $taskPrice.coverPrices.C2 -ne 52 -or $taskPrice.coverPrices.C3 -ne 20) {
        throw 'Unexpected travel premium.'
    }
    $taskBadStatus = 0
    try {
        $null = Invoke-WebRequest 'http://localhost:5041/api/Pricing' -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing
    } catch {
        if ($_.Exception.Response) { $taskBadStatus = [int]$_.Exception.Response.StatusCode } else { throw }
    }
    if ($taskBadStatus -ne 400) { throw "Expected HTTP 400, got $taskBadStatus." }
    $taskReport = [ordered]@{
        checkedAt = [DateTimeOffset]::Now.ToString('o')
        eurekaUrl = 'http://localhost:8761'
        pricingUrl = 'http://localhost:5041'
        health = $taskHealth
        registry = $taskRegistry
        request = $taskRequest
        price = $taskPrice
        invalidRequestHttpStatus = $taskBadStatus
        result = 'PASS'
    }
    $taskReport | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $taskEvidence 'runtime-verification.json') -Encoding utf8
    $taskReport | ConvertTo-Json -Depth 30
    Write-Host 'PASS: PricingService UP in Eureka; premium 98; invalid command HTTP 400.'
} finally { Pop-Location }
