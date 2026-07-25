# Optional Gate 0 comic fixtures using WinRAR rar.exe.
# Safe generated PNGs only — never copyrighted comics.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root 'test\support\cbr_gate0_fixtures'
$work = Join-Path $env:TEMP ("ttsplayer_cbr_gate0_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work, $out | Out-Null

function Find-RarExe {
  $candidates = @(
    (Get-Command rar.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    'C:\Program Files\WinRAR\Rar.exe',
    'C:\Program Files (x86)\WinRAR\Rar.exe'
  ) | Where-Object { $_ -and (Test-Path $_) }
  if (-not $candidates) {
    throw 'rar.exe not found. Install WinRAR or add rar.exe to PATH.'
  }
  return $candidates[0]
}

function Write-Png([string]$path, [int]$seed) {
  # Tiny valid PNG; vary one byte in tEXt-free IDAT payload area via seed marker file sidecars.
  $b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC'
  $bytes = [Convert]::FromBase64String($b64)
  if ($seed -ge 0 -and $seed -lt $bytes.Length) {
    $bytes[$seed % $bytes.Length] = [byte](($bytes[$seed % $bytes.Length] + $seed) % 256)
  }
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
Write-Png (Join-Path $nested 'page_extra.png') 9
Set-Content -Path (Join-Path $pages 'notes.txt') -Value 'gate0 non-image entry' -Encoding ascii

# RAR5 comic-like archive
& $rar a -ep1 -m3 -ma5 (Join-Path $out 'rar5_pages.cbr') (Join-Path $pages '*') | Out-Host

# RAR4 comic-like archive
& $rar a -ep1 -m3 -ma4 (Join-Path $out 'rar4_pages.cbr') (Join-Path $pages 'page_*.png') | Out-Host

# Encrypted
& $rar a -ep1 -m3 -ma5 -hpgate0 (Join-Path $out 'encrypted.cbr') (Join-Path $pages 'page_001.png') | Out-Host

# Larger set for memory observation
$large = Join-Path $work 'large'
New-Item -ItemType Directory -Force -Path $large | Out-Null
1..40 | ForEach-Object {
  Write-Png (Join-Path $large ("big_{0:D3}.png" -f $_)) $_
}
& $rar a -ep1 -m1 -ma5 (Join-Path $out 'large_pages.cbr') (Join-Path $large '*') | Out-Host

# Multi-volume (2 volumes)
& $rar a -ep1 -m3 -ma5 -v8k (Join-Path $out 'multivolume.cbr') (Join-Path $pages '*') | Out-Host

Remove-Item -Recurse -Force $work
Write-Host "Fixtures written to $out"
Get-ChildItem $out | Format-Table Name, Length
