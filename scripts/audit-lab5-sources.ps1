[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOriginal = Join-Path $taskRoot 'submission/lab5/provided'
$taskExtracted = Join-Path $taskRoot '.runtime/lab5-source-audit'
New-Item -ItemType Directory -Force -Path $taskExtracted | Out-Null
$taskArchives = @('PricingService.Api.rar','PricingService.Test.rar','PricingService.IntegrationTest.rar')
$taskHashes = @()
foreach ($taskArchive in $taskArchives) {
    $taskFile = Join-Path $taskOriginal $taskArchive
    $taskHashes += [ordered]@{ archive=$taskArchive; sha256=(Get-FileHash -LiteralPath $taskFile -Algorithm SHA256).Hash }
    tar -xf $taskFile -C $taskExtracted
    if ($LASTEXITCODE -ne 0) { throw "Cannot extract $taskArchive" }
}
$taskFiles = @()
foreach ($taskFile in (Get-ChildItem -LiteralPath $taskExtracted -Recurse -File)) {
    $taskRelative = $taskFile.FullName.Substring($taskExtracted.Length+1).Replace('\','/')
    $taskCurrent = Join-Path $taskRoot $taskRelative
    if (-not (Test-Path -LiteralPath $taskCurrent)) { throw "Missing teacher file: $taskRelative" }
    $taskSame = (Get-Content -Raw -LiteralPath $taskFile.FullName).Replace("`r`n","`n") -ceq (Get-Content -Raw -LiteralPath $taskCurrent).Replace("`r`n","`n")
    $taskExpectedChange = $taskRelative -eq 'PricingService.IntegrationTest/IntegrationTestsFixture.cs'
    if (-not $taskSame -and -not $taskExpectedChange) { throw "Unexpected difference: $taskRelative" }
    $taskFiles += [ordered]@{ file=$taskRelative; identicalIgnoringLineEndings=$taskSame; documentedFixtureAdaptation=$taskExpectedChange }
}
$taskResult = [ordered]@{result='PASS';archives=$taskHashes;files=$taskFiles}
$taskEvidence = Join-Path $taskRoot 'submission/lab5/evidence'
New-Item -ItemType Directory -Force -Path $taskEvidence | Out-Null
$taskResult | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $taskEvidence 'teacher-source-audit.json') -Encoding utf8
Write-Host "PASS: $($taskFiles.Count) teacher files present; only the documented integration fixture differs."
