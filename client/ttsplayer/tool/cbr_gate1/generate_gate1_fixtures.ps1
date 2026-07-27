# Generates Gate 1 DLL fixture matrix (local only; large archives gitignored).
param(
  [string]$RarExe = '',
  [string]$UnrarExe = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate0 = Join-Path $root 'test\support\cbr_gate0_fixtures'
$out = Join-Path $root 'test\support\cbr_gate1_fixtures'
$manifest = Join-Path $out 'manifest.json'
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Find-RarExe {
  if ($RarExe -and (Test-Path -LiteralPath $RarExe)) { return (Resolve-Path -LiteralPath $RarExe).Path }
  $candidates = @(
    (Join-Path $root 'tool\cbr_gate0\staging\winrar_extract\Rar.exe'),
    'C:\Program Files\WinRAR\Rar.exe'
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
  if (-not $candidates) { throw 'Rar.exe required for Gate 1 fixture generation.' }
  return $candidates[0]
}

function Write-Png([string]$path, [int]$seed) {
  $b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC'
  $bytes = [Convert]::FromBase64String($b64)
  $bytes[$seed % $bytes.Length] = [byte](($bytes[$seed % $bytes.Length] + $seed) % 256)
  [IO.File]::WriteAllBytes($path, $bytes)
}

$rar = Find-RarExe
$work = Join-Path $env:TEMP ("tts_gate1_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$pages = Join-Path $work 'pages'
New-Item -ItemType Directory -Force -Path $pages | Out-Null

# Unicode filename fixtures
$unicodeNames = @{
  'latin_ea.jpg' = 'page_ea.jpg'
  'greek.jpg' = ([string]::new(@([char]0x0395,[char]0x03BB,[char]0x03BB,[char]0x03B7,[char]0x03BD,[char]0x03B9,[char]0x03BA))[0] + '.jpg')
  'cyrillic.jpg' = ([char]0x0421 + [char]0x0442 + [char]0x0440 + [char]0x0430 + [char]0x043D + [char]0x0438 + [char]0x0446 + [char]0x0430).ToString() + '.jpg'
  'cjk.jpg' = ([char]0x6F22 + [char]0x5B57).ToString() + '.jpg'
  'emoji.jpg' = 'page_' + [char]0xD83D + [char]0xDE00 + '.jpg'
}
$i = 0
foreach ($kv in $unicodeNames.GetEnumerator()) {
  Write-Png (Join-Path $pages $kv.Value) ($i++)
}

Write-Png (Join-Path $pages 'page_001.png') 1
New-Item -ItemType Directory -Force -Path (Join-Path $pages 'nested') | Out-Null
Write-Png (Join-Path $pages 'nested/page_002.png') 2

& $rar a -ep1 -m3 -ma5 -y (Join-Path $out 'unicode_pages.cbr') (Join-Path $pages '*') | Out-Null
& $rar a -ep1 -s -m3 -ma5 -y (Join-Path $out 'solid_pages.cbr') (Join-Path $pages 'page_001.png') (Join-Path $pages 'nested/page_002.png') | Out-Null

# Truncated valid archive
Copy-Item (Join-Path $gate0 'rar5_pages.cbr') (Join-Path $out 'truncated.cbr') -ErrorAction SilentlyContinue
if (Test-Path (Join-Path $out 'truncated.cbr')) {
  $bytes = [IO.File]::ReadAllBytes((Join-Path $out 'truncated.cbr'))
  [IO.File]::WriteAllBytes((Join-Path $out 'truncated.cbr'), $bytes[0..([Math]::Min(256, $bytes.Length - 1))])
}

$entries = @()
Get-ChildItem -LiteralPath $out -File | ForEach-Object {
  $entries += @{
    name = $_.Name
    bytes = $_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()
  }
}

$doc = @{
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  generator = 'tool/cbr_gate1/generate_gate1_fixtures.ps1'
  rar_exe = $rar
  committed = $false
  fixtures = $entries
} | ConvertTo-Json -Depth 5
Set-Content -Path $manifest -Value $doc -Encoding UTF8

Remove-Item -Recurse -Force $work
Write-Host "Gate 1 fixtures written to $out"
Get-ChildItem -LiteralPath $out | Format-Table Name, Length
