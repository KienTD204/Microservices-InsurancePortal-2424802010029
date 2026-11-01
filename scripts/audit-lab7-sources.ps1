[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskProvided = Join-Path $taskRoot 'submission/lab7/provided'
$taskAuditRoot = Join-Path $taskRoot ('.runtime/lab7-audit-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $taskAuditRoot | Out-Null
$taskFiles = @()
$taskArchives = @()
$taskAdaptations = @{
    'PaymentService/Messaging/RabbitMq/RabbitEventListener.cs' = 'Inherited: await the notification handler before disposing its dependency scope.'
    'PaymentService/Startup.cs' = 'Wait for Marten demo/schema initialization before accepting HTTP requests or policy events.'
    'PaymentService.Test/PaymentService.Test.csproj' = 'Add Testcontainers.PostgreSql 3.9.0 for tests against an isolated PostgreSQL 16 database.'
}
function Get-NormalizedHash([string]$Path) {
    $taskText = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $taskSha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($taskSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($taskText)))).Replace('-', '').ToLowerInvariant() }
    finally { $taskSha.Dispose() }
}
foreach ($taskName in @('PaymentService','PaymentService.Api','PaymentService.Test','ProductService','ProductService.Api','ProductService.Test')) {
    $taskArchive = Join-Path $taskProvided "$taskName.rar"
    tar -xf $taskArchive -C $taskAuditRoot
    if ($LASTEXITCODE -ne 0) { throw "Cannot extract $taskArchive" }
    $taskArchives += [pscustomobject]@{name="$taskName.rar"; sha256=(Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant()}
    foreach ($taskFile in Get-ChildItem -LiteralPath (Join-Path $taskAuditRoot $taskName) -Recurse -File) {
        $taskRelative = $taskFile.FullName.Substring($taskAuditRoot.Length + 1).Replace('\','/')
        $taskTarget = Join-Path $taskRoot $taskRelative
        $taskSourceHash = Get-NormalizedHash $taskFile.FullName
        $taskTargetHash = if (Test-Path -LiteralPath $taskTarget) { Get-NormalizedHash $taskTarget } else { $null }
        $taskStatus = if ($null -eq $taskTargetHash) { 'MISSING' } elseif ($taskSourceHash -eq $taskTargetHash) { 'UNCHANGED' } elseif ($taskAdaptations.ContainsKey($taskRelative)) { 'ADAPTED' } else { 'UNREVIEWED' }
        $taskFiles += [pscustomobject]@{path=$taskRelative; status=$taskStatus; reason=$taskAdaptations[$taskRelative]; sourceSha256=$taskSourceHash; solutionSha256=$taskTargetHash}
    }
}
$taskFailures = @($taskFiles | Where-Object { $_.status -in @('MISSING','UNREVIEWED') })
$taskReport = [ordered]@{
    checkedAt=[DateTimeOffset]::Now.ToString('o')
    result=if ($taskFailures.Count -eq 0 -and $taskFiles.Count -eq 107) { 'PASS' } else { 'FAIL' }
    baseCommit='3bbedb0'
    normalization='UTF-8 text, CRLF normalized to LF; original archives are preserved byte for byte.'
    totalFiles=$taskFiles.Count
    summary=@($taskFiles | Group-Object status | ForEach-Object { [pscustomobject]@{status=$_.Name; count=$_.Count} })
    archives=$taskArchives
    files=$taskFiles
}
$taskOutput = Join-Path $taskRoot 'submission/lab7/evidence/teacher-source-audit.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskOutput) | Out-Null
$taskReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $taskOutput -Encoding utf8
$taskReport.summary | Format-Table
if ($taskReport.result -ne 'PASS') { throw 'Teacher source audit failed; inspect teacher-source-audit.json.' }
