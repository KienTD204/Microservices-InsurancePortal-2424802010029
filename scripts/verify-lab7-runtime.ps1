#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskCompose = @('compose','-p','insurance-lab7','-f',(Join-Path $PSScriptRoot 'lab7.docker.yml'))
$taskResults = [System.Collections.Generic.List[object]]::new()
$taskPolicy = 'LAB7-' + [Guid]::NewGuid().ToString('N')
$taskHeaders = @{Authorization='Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('guest:guest'))}
$taskFailure = $null
function Assert-Lab7([string]$Name, [bool]$Condition, $Details) {
    $taskResults.Add([pscustomobject]@{name=$Name; result=if ($Condition) {'PASS'} else {'FAIL'}; details=$Details})
    if (-not $Condition) { throw "Failed: $Name" }
}
function Wait-Lab7Http([string]$Url, [scriptblock]$Ready = { param($Response) $true }) {
    $taskWait = [Diagnostics.Stopwatch]::StartNew()
    while ($taskWait.Elapsed.TotalSeconds -lt 90) {
        try {
            $taskStatus = 0
            $taskResponse = Invoke-RestMethod -Uri $Url -TimeoutSec 5 -MaximumRetryCount 0 -SkipHttpErrorCheck -StatusCodeVariable taskStatus
            if ($taskStatus -eq 200 -and (& $Ready $taskResponse)) { return $taskResponse }
        } catch { }
        Start-Sleep -Seconds 2
    }
    throw "Timed out waiting for $Url"
}
function Invoke-Lab7Sql([string]$Sql) {
    $taskValue = & docker @taskCompose exec -T postgres psql -U lab7_user -d lab7_payments -tA -c $Sql
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL verification failed.' }
    return ($taskValue -join "`n").Trim()
}
function Get-Lab7Document {
    $taskJson = Invoke-Lab7Sql "SELECT data FROM payment_service.mt_doc_policyaccount WHERE coalesce(data->>'PolicyNumber', data->>'policyNumber') = '$taskPolicy';"
    return $taskJson | ConvertFrom-Json
}
function Publish-Lab7Event([string]$Kind, $Event) {
    $taskBody = @{
        properties=@{type="PolicyService.Api.Events.${Kind}, PolicyService.Api"; content_type='application/json'; delivery_mode=2}
        routing_key=$Kind.ToLowerInvariant()
        payload=($Event | ConvertTo-Json -Depth 10 -Compress)
        payload_encoding='string'
    } | ConvertTo-Json -Depth 10 -Compress
    $taskPublished = Invoke-RestMethod -Uri 'http://localhost:15673/api/exchanges/%2F/lab-dotnet-micro/publish' -Method Post -Headers $taskHeaders -ContentType application/json -Body $taskBody
    if (-not $taskPublished.routed) { throw "RabbitMQ did not route $Kind" }
}
try {
    $taskProducts = @(Wait-Lab7Http 'http://localhost:15030/api/Products')
    Assert-Lab7 'Product catalog contains four demo products' ($taskProducts.Count -eq 4) @($taskProducts.code)
    $taskTravel = Wait-Lab7Http 'http://localhost:15030/api/Products/TRI'
    Assert-Lab7 'Travel product includes covers and questions' ($taskTravel.code -eq 'TRI' -and $taskTravel.covers.Count -gt 0 -and $taskTravel.questions.Count -gt 0) @{code=$taskTravel.code; covers=$taskTravel.covers.Count; questions=$taskTravel.questions.Count}
    foreach ($taskNumber in @('POLICY_1','POLICY_2','POLICY_3')) {
        $taskBalance = Wait-Lab7Http "http://localhost:15070/api/Payment/accounts/$taskNumber"
        Assert-Lab7 "Payment API reads $taskNumber from Marten" ($taskBalance.balance.policyNumber -eq $taskNumber -and $taskBalance.balance.balance -eq 0) $taskBalance
    }
    $taskStorageType = Invoke-Lab7Sql 'SELECT pg_typeof(data)::text FROM payment_service.mt_doc_policyaccount LIMIT 1;'
    Assert-Lab7 'PostgreSQL stores policy account documents as jsonb' ($taskStorageType -eq 'jsonb') $taskStorageType
    $taskEvent = @{
        PolicyNumber=$taskPolicy; ProductCode='TRI'; PolicyFrom='2026-01-01T00:00:00Z'; PolicyTo='2026-12-31T00:00:00Z'
        PolicyHolder=@{FirstName='Lab7'; LastName='Verifier'}; TotalPremium=100.55; AgentLogin='lab7.verifier'
    }
    Publish-Lab7Event 'PolicyCreated' $taskEvent
    $taskCreated = Wait-Lab7Http "http://localhost:15070/api/Payment/accounts/$taskPolicy"
    $taskDocument = Get-Lab7Document
    Assert-Lab7 'RabbitMQ PolicyCreated persists an account readable through HTTP' ($taskCreated.balance.policyNumber -eq $taskPolicy -and $taskDocument.owner.firstName -eq 'Lab7') @{response=$taskCreated; documentId=$taskDocument.id; owner=$taskDocument.owner}
    $taskEvent.AmountToReturn = 12.34
    $taskEvent.PolicyTo = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    Publish-Lab7Event 'PolicyTerminated' $taskEvent
    $taskTerminated = Wait-Lab7Http "http://localhost:15070/api/Payment/accounts/$taskPolicy" { param($Response) $Response.balance.balance -eq -12.34 }
    $taskBefore = Get-Lab7Document
    Assert-Lab7 'RabbitMQ PolicyTerminated persists the refund with decimal precision' ($taskTerminated.balance.balance -eq -12.34 -and $taskBefore.entries.Count -eq 1) $taskTerminated
    & docker @taskCompose restart payment
    if ($LASTEXITCODE -ne 0) { throw 'Cannot restart the lab7 payment service.' }
    $taskRestarted = Wait-Lab7Http "http://localhost:15070/api/Payment/accounts/$taskPolicy"
    $taskAfter = Get-Lab7Document
    $taskDemoCount = Invoke-Lab7Sql "SELECT count(*) FROM payment_service.mt_doc_policyaccount WHERE coalesce(data->>'PolicyNumber', data->>'policyNumber') IN ('POLICY_1','POLICY_2','POLICY_3');"
    Assert-Lab7 'Service restart preserves the account and does not duplicate demo data' ($taskRestarted.balance.balance -eq -12.34 -and $taskAfter.id -eq $taskBefore.id -and $taskAfter.entries.Count -eq 1 -and $taskDemoCount -eq '3') @{policyNumber=$taskPolicy; documentId=$taskAfter.id; balance=$taskRestarted.balance.balance; demoAccountCount=[int]$taskDemoCount}
} catch {
    $taskFailure = $_
} finally {
    $taskOutput = Join-Path $taskRoot 'submission/lab7/evidence/runtime-verification.json'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskOutput) | Out-Null
    [ordered]@{checkedAt=[DateTimeOffset]::Now.ToString('o'); result=if ($taskFailure) {'FAIL'} else {'PASS'}; policyNumber=$taskPolicy; checks=$taskResults; error=if ($taskFailure) {$taskFailure.Exception.Message} else {$null}} |
        ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $taskOutput -Encoding utf8
    $taskResults | Select-Object name,result | Format-Table -AutoSize
}
if ($taskFailure) { throw $taskFailure }
