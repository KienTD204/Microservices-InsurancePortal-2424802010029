# Lab 9 - end-to-end check of the deployed system (run after "docker compose ... lab9.docker.yml up").
# Flow: login (JWT) -> products via gateway -> offer (PolicyService calls PricingService) -> policy
#       -> RabbitMQ PolicyCreated -> PolicySearchService (Elasticsearch) + PaymentService (Marten) + DashboardService.
# ASCII only on purpose: the file must parse in Windows PowerShell 5.1 as well as PowerShell 7.
[CmdletBinding()]
param(
    [string]$Gateway = 'http://localhost:8099',
    [string]$Auth = 'http://localhost:6060',
    [string]$Chat = 'http://localhost:4099',
    [string]$Payment = 'http://localhost:5070',
    [string]$Eureka = 'http://localhost:8761'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEvidence = Join-Path $taskRoot 'submission/lab9/evidence'
New-Item -ItemType Directory -Force -Path $taskEvidence | Out-Null
$taskChecks = New-Object System.Collections.ArrayList
$taskRunId = [Guid]::NewGuid().ToString('N').Substring(0, 8)

function Add-Check([string]$Name, [bool]$Passed, $Detail = $null) {
    $null = $taskChecks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail })
    if ($Passed) { Write-Host "PASS: $Name" -ForegroundColor Green } else { Write-Host "FAIL: $Name" -ForegroundColor Red }
}
function Get-Status([scriptblock]$Call) {
    try { $null = & $Call; return 200 } catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    }
}
function Wait-Until([scriptblock]$Probe, [int]$Attempts = 45) {
    for ($taskAttempt = 0; $taskAttempt -lt $Attempts; $taskAttempt++) {
        try { $taskValue = & $Probe; if ($taskValue) { return $taskValue } } catch { }
        Start-Sleep -Seconds 2
    }
    return $null
}

$taskFailure = $null
try {
    # 1. Service discovery
    $taskExpected = @('PRODUCTSERVICE', 'PRICINGSERVICE', 'POLICYSERVICE', 'POLICYSEARCHSERVICE', 'DASHBOARDSERVICE')
    $taskUp = Wait-Until {
        $taskRegistry = Invoke-RestMethod "$Eureka/eureka/apps" -Headers @{ Accept = 'application/json' }
        $taskNames = @($taskRegistry.applications.application | Where-Object { @($_.instance | Where-Object { $_.status -eq 'UP' }).Count -gt 0 } | ForEach-Object { $_.name })
        if (@($taskExpected | Where-Object { $_ -notin $taskNames }).Count -eq 0) { $taskNames }
    }
    Add-Check 'Eureka shows Product, Pricing, Policy, PolicySearch and Dashboard services UP' ($null -ne $taskUp) $taskUp
    if (-not $taskUp) { throw 'Services are not registered in Eureka.' }

    # 2. Security
    $taskAnonymous = Get-Status { Invoke-WebRequest "$Gateway/api/Products" -UseBasicParsing }
    Add-Check 'Gateway blocks anonymous requests (HTTP 401)' ($taskAnonymous -eq 401) $taskAnonymous
    $taskLogin = Invoke-RestMethod "$Auth/api/User" -Method Post -ContentType 'application/json' -Body '{"login":"jimmy.solid","password":"secret"}'
    Add-Check 'AuthService issues a JWT for jimmy.solid' (($taskLogin.token -split '\.').Count -eq 3)
    $taskHeaders = @{ Authorization = "Bearer $($taskLogin.token)" }

    # 3. Product catalogue through gateway + Eureka
    $taskProducts = Wait-Until { $taskList = @(Invoke-RestMethod "$Gateway/api/Products" -Headers $taskHeaders); if ($taskList.Count -gt 0) { $taskList } }
    Add-Check 'Gateway -> ProductService returns the product catalogue' (@($taskProducts | Where-Object { $_.code -eq 'TRI' }).Count -eq 1) (@($taskProducts | ForEach-Object { $_.code }) -join ',')

    # 4. Offer: PolicyService -> PricingService (REST)
    $taskFrom = (Get-Date).Date.AddDays(1)
    $taskOfferBody = @{
        productCode    = 'TRI'
        policyFrom     = $taskFrom.ToString('yyyy-MM-ddTHH:mm:ss')
        policyTo       = $taskFrom.AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss')
        selectedCovers = @('C2', 'C3')
        answers        = @(
            @{ questionCode = 'DESTINATION'; questionType = 'Choice'; answer = 'EUR' },
            @{ questionCode = 'NUM_OF_ADULTS'; questionType = 'Numeric'; answer = 2 },
            @{ questionCode = 'NUM_OF_CHILDREN'; questionType = 'Numeric'; answer = 1 }
        )
    } | ConvertTo-Json -Depth 5
    $taskOffer = Wait-Until { Invoke-RestMethod "$Gateway/api/Offers" -Method Post -Headers $taskHeaders -ContentType 'application/json' -Body $taskOfferBody } 20
    Add-Check 'Offer created and priced by PricingService' ($taskOffer -and $taskOffer.offerNumber -and $taskOffer.totalPrice -gt 0) $taskOffer
    if (-not $taskOffer) { throw 'Offer was not created.' }

    # 5. Policy: offer -> policy, event published to RabbitMQ through the outbox
    $taskLastName = "Lab9$taskRunId"
    $taskPolicyBody = @{
        offerNumber         = $taskOffer.offerNumber
        policyHolder        = @{ firstName = 'Kien'; lastName = $taskLastName; taxId = '2424802010029' }
        policyHolderAddress = @{ country = 'VN'; zipCode = '75000'; city = 'Thu Dau Mot'; street = '06 Tran Van On' }
    } | ConvertTo-Json -Depth 5
    $taskPolicy = Invoke-RestMethod "$Gateway/api/Policies" -Method Post -Headers $taskHeaders -ContentType 'application/json' -Body $taskPolicyBody
    Add-Check 'Policy created from the offer' ([bool]$taskPolicy.policyNumber) $taskPolicy.policyNumber
    $taskDetails = Invoke-RestMethod "$Gateway/api/Policies/$($taskPolicy.policyNumber)" -Headers $taskHeaders
    Add-Check 'Policy details can be read back through the gateway' ($taskDetails.policy.number -eq $taskPolicy.policyNumber) $taskDetails.policy

    # 6. PolicySearchService: RabbitMQ -> Elasticsearch -> search API
    $taskFound = Wait-Until {
        $taskResult = Invoke-RestMethod "$Gateway/api/PolicySearch?q=$taskLastName" -Headers $taskHeaders
        @($taskResult.policies | Where-Object { $_.policyNumber -eq $taskPolicy.policyNumber }) | Select-Object -First 1
    }
    Add-Check 'PolicySearchService indexed the new policy and finds it by policy holder' ($null -ne $taskFound) $taskFound

    # 7. PaymentService: RabbitMQ -> policy account in Marten/PostgreSQL
    $taskAccount = Wait-Until { Invoke-RestMethod "$Payment/api/Payment/accounts/$($taskPolicy.policyNumber)" }
    Add-Check 'PaymentService opened a policy account for the new policy' ($null -ne $taskAccount) $taskAccount

    # 8. DashboardService through the gateway
    $taskSales = Wait-Until { Invoke-RestMethod "$Gateway/api/Dashboard/total-sales" -Method Post -Headers $taskHeaders -ContentType 'application/json' -Body '{}' } 15
    Add-Check 'DashboardService returns total sales' ($null -ne $taskSales) $taskSales

    # 9. ChatService (SignalR): anonymous is rejected, JWT is accepted
    $taskChatAnonymous = Get-Status { Invoke-WebRequest "$Chat/agentsChat/negotiate?negotiateVersion=1" -Method Post -UseBasicParsing }
    $taskNegotiate = Invoke-RestMethod "$Chat/agentsChat/negotiate?negotiateVersion=1" -Method Post -Headers $taskHeaders
    Add-Check 'ChatService SignalR hub: anonymous 401, JWT negotiation succeeds' ($taskChatAnonymous -eq 401 -and [bool]$taskNegotiate.connectionId) $taskChatAnonymous
} catch {
    $taskFailure = $_.Exception.Message
    Write-Host "ERROR: $taskFailure" -ForegroundColor Red
}

$taskFailed = @($taskChecks | Where-Object { -not $_.passed })
$taskReport = [ordered]@{
    checkedAt = [DateTimeOffset]::Now.ToString('o')
    result    = if (-not $taskFailure -and $taskFailed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    error     = $taskFailure
    passed    = @($taskChecks | Where-Object { $_.passed }).Count
    total     = $taskChecks.Count
    checks    = $taskChecks
}
$taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskEvidence 'runtime-verification.json') -Encoding utf8
Write-Host ''
Write-Host "Result: $($taskReport.result) ($($taskReport.passed)/$($taskReport.total)). Report: submission/lab9/evidence/runtime-verification.json"
if ($taskReport.result -ne 'PASS') { exit 1 }
