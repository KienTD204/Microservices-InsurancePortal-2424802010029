[CmdletBinding()]
param([switch]$SkipBuild, [switch]$SkipInfra)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskRuntime = Join-Path $taskRoot '.runtime/lab6'
New-Item -ItemType Directory -Force -Path $taskRuntime | Out-Null
Push-Location $taskRoot
try {
    if (-not $SkipBuild) {
        dotnet build DotNetMicroservicesPoc.sln -c Release --nologo
        if ($LASTEXITCODE -ne 0) { throw 'Solution build failed.' }
    }
    if (-not $SkipInfra) {
        docker compose -p insurance-lab -f scripts/infra.windows.yml up -d --build eureka rabbitmq elasticsearch
        if ($LASTEXITCODE -ne 0) { throw 'Infrastructure start failed. Open Docker Desktop with the Linux engine.' }
    }
    foreach ($taskUrl in @('http://localhost:8761', 'http://localhost:9200', 'http://localhost:15672')) {
        $taskReady = $false
        for ($taskAttempt = 0; $taskAttempt -lt 60; $taskAttempt++) {
            try {
                $null = Invoke-WebRequest $taskUrl -UseBasicParsing -TimeoutSec 3
                $taskReady = $true; break
            } catch { Start-Sleep -Seconds 2 }
        }
        if (-not $taskReady) { throw "Not ready: $taskUrl" }
    }

    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:DOTNET_ENVIRONMENT = 'Development'
    $env:Logging__EventLog__LogLevel__Default = 'None'
    $env:Eureka__Client__ShouldFetchRegistry = 'true'
    $env:Eureka__Instance__HostName = 'localhost'
    $taskPorts = [ordered]@{AuthService=6060; ProductService=5030; ChatService=4099; DashboardService=5035; AgentPortalApiGateway=8099}
    $taskProcesses = @()
    $taskProcessFile = Join-Path $taskRuntime 'processes.json'
    if (Test-Path -LiteralPath $taskProcessFile) {
        $taskProcesses = @(Get-Content -LiteralPath $taskProcessFile -Raw | ConvertFrom-Json)
    }
    foreach ($taskService in $taskPorts.Keys) {
        $taskPort = $taskPorts[$taskService]
        $taskListener = @(Get-NetTCPConnection -LocalPort $taskPort -State Listen -ErrorAction SilentlyContinue)
        if ($taskListener.Count -gt 0) {
            $taskKnown = @($taskProcesses | Where-Object { $_.Service -eq $taskService -and $_.PID -in $taskListener.OwningProcess })
            if ($taskKnown.Count -gt 0) { Write-Host "Already started by this script: $taskService"; continue }
            throw "Port $taskPort is in use. Stop the existing lab service before starting this copy."
        }
        $taskDirectory = Join-Path $taskRoot $taskService
        $taskDll = Join-Path $taskDirectory "bin/Release/net8.0/$taskService.dll"
        if (-not (Test-Path -LiteralPath $taskDll)) { throw "Build Release first: $taskService" }
        $env:Eureka__Instance__Port = [string]$taskPort
        $env:Eureka__Client__ShouldRegisterWithEureka = if ($taskService -eq 'AgentPortalApiGateway') { 'false' } else { 'true' }
        $env:ASPNETCORE_URLS = "http://localhost:$taskPort"
        $taskProcess = Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList @("`"$taskDll`"", '--urls', "http://localhost:$taskPort") -WorkingDirectory $taskDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRuntime "$taskService.stdout.txt") -RedirectStandardError (Join-Path $taskRuntime "$taskService.stderr.txt")
        $taskProcesses += [pscustomobject]@{Service=$taskService; PID=$taskProcess.Id; Port=$taskPort; Dll=$taskDll}
        $taskProcesses | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $taskProcessFile -Encoding utf8
    }
    foreach ($taskPort in @(6060,5030,4099,5035)) {
        $taskReady = $false
        for ($taskAttempt = 0; $taskAttempt -lt 60; $taskAttempt++) {
            try {
                $null = Invoke-WebRequest "http://localhost:$taskPort/swagger/v1/swagger.json" -UseBasicParsing -TimeoutSec 3
                $taskReady = $true; break
            } catch { Start-Sleep -Seconds 2 }
        }
        if (-not $taskReady) { throw "Service on port $taskPort failed to start. See .runtime/lab6 logs." }
    }
    Write-Host 'Lab 6 started. Run scripts/verify-lab6.ps1 to check Gateway, JWT, SignalR, RabbitMQ and Dashboard.'
} finally { Pop-Location }
