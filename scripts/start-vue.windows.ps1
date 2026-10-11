[CmdletBinding()]
param([string]$NodeExecutable='node')
$ErrorActionPreference='Stop'
$taskNode=(Get-Command $NodeExecutable -ErrorAction Stop).Source
$taskVersion=& $taskNode --version
if($taskVersion -notlike 'v10.*') {throw 'Web source dùng node-sass 4.9.2; truyền đường dẫn Node 10.24.0 vào -NodeExecutable.'}
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskWeb=Join-Path $taskRoot 'Web'
$taskRuntime=Join-Path $taskRoot '.runtime'
New-Item -ItemType Directory -Force -Path $taskRuntime | Out-Null
if(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue) {throw 'Port 8080 đang được dùng.'}
if(-not(Test-Path -LiteralPath (Join-Path $taskWeb '.env.local'))) {
    @('VUE_APP_BACKEND_URL=http://localhost:8099/api/','VUE_APP_AUTH_URL=http://localhost:6060/api/','VUE_APP_CHAT_URL=http://localhost:4099') | Set-Content -LiteralPath (Join-Path $taskWeb '.env.local') -Encoding ascii
}
$taskCli=Join-Path $taskWeb 'node_modules\@vue\cli-service\bin\vue-cli-service.js'
if(-not(Test-Path -LiteralPath $taskCli)) {throw 'Chạy npm ci trong Web bằng Node 10 trước.'}
$taskProcess=Start-Process -FilePath $taskNode -ArgumentList @($taskCli,'serve','--host','localhost','--port','8080') -WorkingDirectory $taskWeb -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRuntime 'Web.stdout.txt') -RedirectStandardError (Join-Path $taskRuntime 'Web.stderr.txt')
[pscustomobject]@{Service='Web';PID=$taskProcess.Id;Port=8080;Node=$taskVersion} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRuntime 'vue-process.json') -Encoding utf8
Write-Host 'Vue đang khởi động ở http://localhost:8080; xem .runtime/Web.stdout.txt.'
