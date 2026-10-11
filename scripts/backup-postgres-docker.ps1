<#
Mẫu dành cho sinh viên: chưa chạy trên Docker trong phiên phân tích.
Đọc hướng dẫn trước; script tạo bốn Custom-format dumps, kiểm tra TOC,
chép nhị phân bằng docker cp và tạo manifest. Không xóa database/volume.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]*$')]
    [string]$ContainerName = 'postgres'
)

$ErrorActionPreference = 'Stop'
Get-Command docker -ErrorAction Stop | Out-Null
$taskBackupDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $taskBackupDirectory | Out-Null
$taskDatabases = @('lab_netmicro_payments','lab_netmicro_jobs','lab_netmicro_policy','lab_netmicro_pricing')

foreach ($taskDb in $taskDatabases) {
    $taskFile = Join-Path $taskBackupDirectory "$taskDb.backup"
    if (Test-Path -LiteralPath $taskFile) {
        throw "Đã có $taskFile. Chọn thư mục mới để giữ bản backup trước."
    }
}

$taskVersion = & docker exec $ContainerName psql -U postgres -d postgres -t -A -c 'SELECT version();'
if ($LASTEXITCODE -ne 0) { throw 'Không kết nối được PostgreSQL trong container.' }
$taskToolVersion = & docker exec $ContainerName pg_dump --version
if ($LASTEXITCODE -ne 0) { throw 'Không lấy được version pg_dump.' }
@("Backup time: $(Get-Date -Format o)","Server: $taskVersion","Tool: $taskToolVersion") |
    Set-Content -LiteralPath (Join-Path $taskBackupDirectory 'backup-environment.txt') -Encoding utf8

foreach ($taskDb in $taskDatabases) {
    $taskFile = Join-Path $taskBackupDirectory "$taskDb.backup"
    & docker exec $ContainerName pg_dump -U postgres -d $taskDb -Fc -f "/tmp/$taskDb.backup"
    if ($LASTEXITCODE -ne 0) { throw "pg_dump thất bại: $taskDb" }
    $taskToc = & docker exec $ContainerName pg_restore -l "/tmp/$taskDb.backup"
    if ($LASTEXITCODE -ne 0) { throw "Không đọc được archive: $taskDb" }
    $taskToc | Set-Content -LiteralPath (Join-Path $taskBackupDirectory "$taskDb-toc.txt") -Encoding utf8
    & docker cp "${ContainerName}:/tmp/$taskDb.backup" $taskFile
    if ($LASTEXITCODE -ne 0) { throw "docker cp thất bại: $taskDb" }
    if ((Get-Item -LiteralPath $taskFile).Length -eq 0) { throw "File rỗng: $taskDb" }
    Write-Host "Đã tạo $taskFile; còn cần thử restore vào DB kiểm tra."
}

$taskManifest = foreach ($taskDb in $taskDatabases) {
    $taskFile = Get-Item -LiteralPath (Join-Path $taskBackupDirectory "$taskDb.backup")
    $taskHash = Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256
    [pscustomobject]@{ File=$taskFile.Name; Bytes=$taskFile.Length; SHA256=$taskHash.Hash }
}
$taskManifest | Export-Csv -LiteralPath (Join-Path $taskBackupDirectory 'backup-manifest.csv') -NoTypeInformation -Encoding utf8
Write-Host 'Backup và TOC đã tạo; xem hướng dẫn phần 12 để thử restore và viết RESTORE.md.'
