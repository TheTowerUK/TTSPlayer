param(
    [string]$Repo = 'D:\AppDev\TTSPlayer',
    [string]$Flutter = 'D:\Tools\flutter\bin\flutter.bat',
    [string]$EvidenceRoot = 'D:\TTSPlayer-validation'
)

# No production preferences, media, catalogue, version or Git history are changed.
# dart format may format the new test file only.
$testRelative = 'test/phase_78_provider_windows_runtime_test.dart'
$clientPath = Join-Path $Repo 'client\ttsplayer'
$dartPath = Join-Path (Split-Path $Flutter) 'dart.bat'
foreach ($required in @($Flutter, $dartPath, (Join-Path $clientPath $testRelative))) {
    if (!(Test-Path -LiteralPath $required)) { throw "Required path missing: $required" }
}
$evidencePath = Join-Path $EvidenceRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Path $evidencePath -Force -ErrorAction Stop | Out-Null
$oldRuntime = [Environment]::GetEnvironmentVariable('PHASE_78_RUNTIME','Process')
$oldPath = $env:Path
Push-Location $clientPath
try {
    $env:Path = "$(Split-Path $Flutter);$env:Path"
    & $dartPath format $testRelative 2>&1 | Tee-Object (Join-Path $evidencePath 'format.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Formatting failed' }
    & $Flutter analyze $testRelative 2>&1 | Tee-Object (Join-Path $evidencePath 'analyze.txt')
    if ($LASTEXITCODE -ne 0) { throw 'New-test analysis failed; share the log before continuing' }
    $env:PHASE_78_RUNTIME = '1'
    & $Flutter test $testRelative --reporter expanded 2>&1 | Tee-Object (Join-Path $evidencePath 'runtime.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Phase 7.8 runtime validation failed; share the log' }
    Write-Host "Phase 7.8 automated matrix passed. Evidence: $evidencePath"
    Write-Host 'Manual artwork/export checks and final release gates remain.'
}
finally {
    [Environment]::SetEnvironmentVariable('PHASE_78_RUNTIME',$oldRuntime,'Process')
    $env:Path = $oldPath
    Pop-Location
}
