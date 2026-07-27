# Gate 1 Release-layout CBR smoke (Windows only).
# Copies approved eval DLL into Release unrar/ subdir and runs harness without PHASE_63_UNRAR_DLL.
param(
  [string]$EvalDll = '',
  [string]$EvalLicense = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

if (-not $EvalDll) {
  $EvalDll = Join-Path $root 'third_party\_gate1_eval\unrardll-723\x64\UnRAR64.dll'
}
if (-not $EvalLicense) {
  $EvalLicense = Join-Path $root 'third_party\_gate1_eval\unrardll-723\license.txt'
}
if (-not (Test-Path -LiteralPath $EvalDll)) {
  throw "Eval DLL not found: $EvalDll"
}
if (-not (Test-Path -LiteralPath $EvalLicense)) {
  throw "Eval license not found: $EvalLicense"
}

Write-Host 'Building Windows Release...'
flutter build windows --release | Out-Host

$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$unrarDir = Join-Path $releaseDir 'unrar'
New-Item -ItemType Directory -Force -Path $unrarDir | Out-Null

Copy-Item -LiteralPath $EvalDll -Destination (Join-Path $unrarDir 'UnRAR64.dll') -Force
Copy-Item -LiteralPath $EvalLicense -Destination (Join-Path $unrarDir 'license.txt') -Force

$dllHash = (Get-FileHash -LiteralPath (Join-Path $unrarDir 'UnRAR64.dll') -Algorithm SHA256).Hash.ToLower()
$expected = '894b7d2db8d6363eb12f30c7b89f48eab9e71963b8b438675bdd64c12dd59bcc'
if ($dllHash -ne $expected) {
  throw "DLL hash mismatch in Release layout: $dllHash"
}
Write-Host "Release DLL hash OK: $dllHash"

Remove-Item Env:PHASE_63_UNRAR_DLL -ErrorAction SilentlyContinue
$env:PHASE_63_CBR_PRODUCTION = '1'
$env:PHASE_63_RELEASE_APP_DIR = $releaseDir

Write-Host 'Running Gate 1 harness (bundled Release layout)...'
flutter test test/phase_63_cbr_production_windows_runtime_test.dart --tags phase63-cbr-production | Out-Host

Write-Host 'Release smoke without DLL...'
Remove-Item -LiteralPath (Join-Path $unrarDir 'UnRAR64.dll') -Force
flutter test test/phase_63_cbr_production_windows_runtime_test.dart --tags phase63-cbr-production -n "G1-05 missing DLL" 2>$null

Write-Host 'Done.'
