[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskProcessFile = Join-Path $taskRoot '.runtime/lab6/processes.json'
if (-not (Test-Path -LiteralPath $taskProcessFile)) { return }
$taskRemaining = @()
foreach ($taskItem in @(Get-Content -LiteralPath $taskProcessFile -Raw | ConvertFrom-Json)) {
    $taskProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($taskItem.PID)" -ErrorAction SilentlyContinue
    if ($taskProcess -and $taskProcess.Name -eq 'dotnet.exe' -and $taskProcess.CommandLine.Contains($taskItem.Dll)) {
        Stop-Process -Id $taskItem.PID
        Write-Host "Stopped $($taskItem.Service)."
    } elseif ($taskProcess) {
        $taskRemaining += $taskItem
        Write-Warning "PID $($taskItem.PID) no longer matches the saved lab process; left running."
    }
}
ConvertTo-Json -InputObject @($taskRemaining) -Depth 4 | Set-Content -LiteralPath $taskProcessFile -Encoding utf8
