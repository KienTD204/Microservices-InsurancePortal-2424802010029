[CmdletBinding()]
param([switch]$SkipBlazor)
$ErrorActionPreference = 'Stop'
$taskSourceRoot = Split-Path -Parent $PSScriptRoot
$taskRuntime = Join-Path $taskSourceRoot '.runtime'
New-Item -ItemType Directory -Force -Path $taskRuntime | Out-Null
$taskPorts = [ordered]@{AuthService=6060; ChatService=4099; ProductService=5030; PricingService=5041; PolicyService=5050; PolicySearchService=5065; PaymentService=5070; DashboardService=5035; AgentPortalApiGateway=8099}
$env:ASPNETCORE_ENVIRONMENT='Development'
$env:DOTNET_ENVIRONMENT='Development'
$env:Logging__EventLog__LogLevel__Default='None'
$env:Eureka__Instance__HostName='localhost'
$env:BackgroundJobs__InPaymentFileFolder=Join-Path $PSScriptRoot 'payment-input'
New-Item -ItemType Directory -Force -Path $env:BackgroundJobs__InPaymentFileFolder | Out-Null
$taskProcesses = @()
if (Test-Path -LiteralPath (Join-Path $taskRuntime 'processes.json')) {
    $taskProcesses = @(Get-Content -LiteralPath (Join-Path $taskRuntime 'processes.json') -Raw | ConvertFrom-Json)
}
foreach ($taskService in $taskPorts.Keys) {
    $taskPort = $taskPorts[$taskService]
    $taskListener = @(Get-NetTCPConnection -LocalPort $taskPort -State Listen -ErrorAction SilentlyContinue)
    $taskKnown = @($taskProcesses | Where-Object {$_.Service -eq $taskService})
    if ($taskListener.Count -gt 0) {
        if ($taskKnown.Count -gt 0 -and $taskKnown[-1].PID -in $taskListener.OwningProcess) { Write-Host "$taskService đã chạy bởi script này."; continue }
        throw "Port $taskPort đang được dùng; kiểm tra trước khi chạy lại."
    }
    $taskDirectory = Join-Path $taskSourceRoot $taskService
    $taskDll = Join-Path $taskDirectory "bin\Release\net8.0\$taskService.dll"
    if (-not (Test-Path -LiteralPath $taskDll)) { throw "Chưa build Release: $taskService" }
    $env:ASPNETCORE_URLS="http://localhost:$taskPort"
    $env:Eureka__Instance__Port=[string]$taskPort
    $taskProcess=Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList @($taskDll,'--urls',"http://localhost:$taskPort") -WorkingDirectory $taskDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRuntime "$taskService.stdout.txt") -RedirectStandardError (Join-Path $taskRuntime "$taskService.stderr.txt")
    $taskProcesses += [pscustomobject]@{Service=$taskService; PID=$taskProcess.Id; Port=$taskPort; Started=(Get-Date -Format o)}
    $taskProcesses | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $taskRuntime 'processes.json') -Encoding utf8
    Write-Host "Đã khởi động $taskService (PID $($taskProcess.Id)); còn cần kiểm tra API."
}
if (-not $SkipBlazor) {
    if (Get-NetTCPConnection -LocalPort 5081 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 5081 đang được dùng.' }
    $env:ASPNETCORE_URLS='http://localhost:5081'
    $taskDirectory=Join-Path $taskSourceRoot 'BlazorWasmClient'
    $taskProcess=Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList @('run','-c','Release','--no-build','--no-restore','--no-launch-profile','--urls','http://localhost:5081') -WorkingDirectory $taskDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRuntime 'BlazorWasmClient.stdout.txt') -RedirectStandardError (Join-Path $taskRuntime 'BlazorWasmClient.stderr.txt')
    $taskProcesses += [pscustomobject]@{Service='BlazorWasmClient'; PID=$taskProcess.Id; Port=5081; Started=(Get-Date -Format o)}
    $taskProcesses | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $taskRuntime 'processes.json') -Encoding utf8
}
