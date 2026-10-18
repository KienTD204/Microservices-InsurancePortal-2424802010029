[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
    docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) { throw 'Hay mo Docker Desktop voi Linux engine truoc.' }
    docker compose -p insurance-lab -f scripts/infra.windows.yml up -d --build eureka postgres
    if ($LASTEXITCODE -ne 0) { throw 'Khong khoi dong duoc Eureka/PostgreSQL.' }
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 60; $taskAttempt++) {
        try {
            $taskResponse = Invoke-WebRequest 'http://localhost:8761' -UseBasicParsing -TimeoutSec 3
            if ($taskResponse.StatusCode -eq 200) { $taskReady = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $taskReady) { throw 'Eureka chua san sang. Xem docker logs eureka-server.' }
    Write-Host 'Eureka: http://localhost:8761 | Pricing Swagger: http://localhost:5041/swagger'
    Write-Host 'PricingService chay o terminal nay; nhan Ctrl+C de dung.'
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:Logging__EventLog__LogLevel__Default = 'None'
    $env:Eureka__Client__ShouldRegisterWithEureka = 'true'
    $env:Eureka__Client__ShouldFetchRegistry = 'true'
    dotnet run --project ./PricingService
    if ($LASTEXITCODE -ne 0) { throw 'PricingService ket thuc voi loi.' }
} finally { Pop-Location }
