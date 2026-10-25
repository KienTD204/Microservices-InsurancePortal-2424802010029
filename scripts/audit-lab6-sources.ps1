[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskProvided = Join-Path $taskRoot 'submission/lab6/provided'
$taskAuditRoot = Join-Path $taskRoot ('.runtime/lab6-audit-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $taskAuditRoot | Out-Null
$taskFiles = @()
$taskArchives = @()
function Get-NormalizedHash([string]$Path) {
    $taskText = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $taskSha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($taskSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($taskText)))).Replace('-', '').ToLowerInvariant() }
    finally { $taskSha.Dispose() }
}
foreach ($taskName in @('AuthService','ChatService','ChatService.Api','DashboardService','DashboardService.Api','DashboardService.Test')) {
    $taskArchive = Join-Path $taskProvided "$taskName.rar"
    tar -xf $taskArchive -C $taskAuditRoot
    if ($LASTEXITCODE -ne 0) { throw "Cannot extract $taskArchive" }
    $taskArchives += [pscustomobject]@{name="$taskName.rar"; sha256=(Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant()}
    foreach ($taskFile in Get-ChildItem -LiteralPath (Join-Path $taskAuditRoot $taskName) -Recurse -File) {
        $taskRelative = $taskFile.FullName.Substring($taskAuditRoot.Length + 1).Replace('\','/')
        $taskTarget = Join-Path $taskRoot $taskRelative
        $taskSourceHash = Get-NormalizedHash $taskFile.FullName
        $taskTargetHash = if (Test-Path -LiteralPath $taskTarget) { Get-NormalizedHash $taskTarget } else { $null }
        $taskStatus = if ($null -eq $taskTargetHash) { 'MISSING' } elseif ($taskSourceHash -eq $taskTargetHash) { 'UNCHANGED' } else { 'ADAPTED' }
        $taskFiles += [pscustomobject]@{path=$taskRelative; status=$taskStatus; sourceSha256=$taskSourceHash; solutionSha256=$taskTargetHash}
    }
}
$taskReport = [ordered]@{
    checkedAt=[DateTimeOffset]::Now.ToString('o'); result=if (@($taskFiles | Where-Object status -eq 'MISSING').Count -eq 0) { 'PASS' } else { 'FAIL' }
    normalization='UTF-8 text, CRLF normalized to LF; original archives are preserved byte for byte.'
    summary=@($taskFiles | Group-Object status | ForEach-Object { [pscustomobject]@{status=$_.Name; count=$_.Count} })
    archives=$taskArchives; files=$taskFiles
}
$taskOutput = Join-Path $taskRoot 'submission/lab6/evidence/teacher-source-audit.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskOutput) | Out-Null
$taskReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $taskOutput -Encoding utf8
$taskReport.summary | Format-Table
if ($taskReport.result -ne 'PASS') { throw 'Some teacher files are missing.' }
