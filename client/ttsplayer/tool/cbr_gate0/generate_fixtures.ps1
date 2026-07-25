# Optional Gate 0 comic fixtures using WinRAR rar.exe (tooling only - not shipped).
# Safe generated PNGs/JPEGs only - never copyrighted comics.
param(
  [string]$RarExe = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root 'test\support\cbr_gate0_fixtures'
$work = Join-Path $env:TEMP ("ttsplayer_cbr_gate0_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work, $out | Out-Null

function Find-RarExe {
  if ($RarExe -and (Test-Path -LiteralPath $RarExe)) {
    return (Resolve-Path -LiteralPath $RarExe).Path
  }
  $candidates = @(
    (Get-Command rar.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    (Join-Path $PSScriptRoot 'staging\winrar_extract\Rar.exe'),
    'C:\Program Files\WinRAR\Rar.exe',
    'C:\Program Files (x86)\WinRAR\Rar.exe'
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
  if (-not $candidates) {
    throw 'rar.exe not found. Pass -RarExe or extract WinRAR into tool/cbr_gate0/staging/winrar_extract.'
  }
  return $candidates[0]
}

function Write-Png([string]$path, [int]$seed) {
  $b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC'
  $bytes = [Convert]::FromBase64String($b64)
  if ($seed -ge 0 -and $seed -lt $bytes.Length) {
    $bytes[$seed % $bytes.Length] = [byte](($bytes[$seed % $bytes.Length] + $seed) % 256)
  }
  [IO.File]::WriteAllBytes($path, $bytes)
}

function Write-Jpeg([string]$path, [int]$seed) {
  $bytes = [byte[]](
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x03, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
    0x7F, 0xFF, 0xD9
  )
  $bytes[$bytes.Length - 3] = [byte](($bytes[$bytes.Length - 3] + $seed) % 256)
  [IO.File]::WriteAllBytes($path, $bytes)
}

$rar = Find-RarExe
Write-Host "Using $rar"

$pages = Join-Path $work 'pages'
$nested = Join-Path $pages 'nested'
New-Item -ItemType Directory -Force -Path $pages, $nested | Out-Null
1..5 | ForEach-Object {
  Write-Png (Join-Path $pages ("page_{0:D3}.png" -f $_)) $_
}
Write-Jpeg (Join-Path $pages 'page_006.jpg') 6
Write-Png (Join-Path $nested 'page_extra.png') 9
# Unicode filename via codepoints (page_ + U+30E6 U+30CB U+30B3 U+30FC U+30C9 + .png)
$uniName = 'page_' + [string]::new(@(
  [char]0x30E6, [char]0x30CB, [char]0x30B3, [char]0x30FC, [char]0x30C9
)) + '.png'
Write-Png (Join-Path $pages $uniName) 11
Set-Content -Path (Join-Path $pages 'notes.txt') -Value 'gate0 non-image entry' -Encoding ascii

Write-Host 'Creating rar5_pages.cbr'
& $rar a -ep1 -m3 -ma5 -y (Join-Path $out 'rar5_pages.cbr') (Join-Path $pages '*') | Out-Host

Write-Host 'Creating rar4_pages.cbr'
& $rar a -ep1 -m3 -ma4 -y (Join-Path $out 'rar4_pages.cbr') (Join-Path $pages 'page_*.png') (Join-Path $pages 'page_006.jpg') | Out-Host

Write-Host 'Creating encrypted.cbr (password gate0)'
& $rar a -ep1 -m3 -ma5 -y '-hpgate0' (Join-Path $out 'encrypted.cbr') (Join-Path $pages 'page_001.png') | Out-Host

Write-Host 'Creating no_images.cbr'
$textOnly = Join-Path $work 'textonly'
New-Item -ItemType Directory -Force -Path $textOnly | Out-Null
Set-Content -Path (Join-Path $textOnly 'readme.txt') -Value 'no images' -Encoding ascii
& $rar a -ep1 -m3 -ma5 -y (Join-Path $out 'no_images.cbr') (Join-Path $textOnly '*') | Out-Host

Write-Host 'Creating empty_archive.cbr'
$emptyWork = Join-Path $work 'empty_src'
New-Item -ItemType Directory -Force -Path $emptyWork | Out-Null
Set-Content -Path (Join-Path $emptyWork '.keep') -Value '' -Encoding ascii
$emptyArc = Join-Path $out 'empty_archive.cbr'
& $rar a -ep1 -m0 -ma5 -y $emptyArc (Join-Path $emptyWork '.keep') | Out-Host
& $rar d -y $emptyArc '.keep' | Out-Host

Write-Host 'Creating large_pages.cbr'
$large = Join-Path $work 'large'
New-Item -ItemType Directory -Force -Path $large | Out-Null
1..40 | ForEach-Object {
  Write-Png (Join-Path $large ("big_{0:D3}.png" -f $_)) $_
}
& $rar a -ep1 -m1 -ma5 -y (Join-Path $out 'large_pages.cbr') (Join-Path $large '*') | Out-Host

Write-Host 'Creating multivolume.cbr'
& $rar a -ep1 -m3 -ma5 -y -v8k (Join-Path $out 'multivolume.cbr') `
  (Join-Path $pages 'page_001.png') `
  (Join-Path $pages 'page_002.png') `
  (Join-Path $pages 'page_003.png') `
  (Join-Path $pages 'page_004.png') `
  (Join-Path $pages 'page_005.png') | Out-Host

$vols = Get-ChildItem -LiteralPath $out -Filter 'multivolume*' | Sort-Object Name
Write-Host 'Multi-volume outputs:'
$vols | Format-Table Name, Length

# Missing continuation volume: keep only the first volume under a new name
$firstVol = $vols | Select-Object -First 1
if ($firstVol) {
  Copy-Item -LiteralPath $firstVol.FullName -Destination (Join-Path $out 'multivolume_missing_part.cbr') -Force
}

Write-Host 'Creating safe_names_only.cbr'
$trav = Join-Path $work 'trav'
New-Item -ItemType Directory -Force -Path $trav | Out-Null
Write-Png (Join-Path $trav 'evil.png') 3
& $rar a -ep1 -m3 -ma5 -y (Join-Path $out 'safe_names_only.cbr') (Join-Path $trav 'evil.png') | Out-Host

Remove-Item -Recurse -Force $work
Write-Host "Fixtures written to $out"
Get-ChildItem -LiteralPath $out | Format-Table Name, Length
