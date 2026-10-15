$ErrorActionPreference = 'Stop'
if (Get-Process -Name IGTAPfullGame -ErrorAction SilentlyContinue) {
    throw 'Close the game before restoring the original.'
}
$target = Join-Path (Split-Path $PSScriptRoot -Parent) 'Managed\Assembly-CSharp.dll'
$backup = Join-Path $PSScriptRoot 'Assembly-CSharp.dll.original'
$current = [IO.File]::ReadAllBytes($target)
$original = [IO.File]::ReadAllBytes($backup)
if ($current.Length -ne $original.Length) { throw 'Game version changed; use Steam file verification instead.' }
$differences = @()
for ($i = 0; $i -lt $current.Length; $i++) {
    if ($current[$i] -ne $original[$i]) { $differences += $i }
}
if ($differences.Count -eq 0) { Write-Output 'Original is already installed.'; return }
if ($differences.Count -ne 2 -or $differences[1] -ne ($differences[0] + 1) -or
    $original[$differences[0]] -ne 7 -or $original[$differences[1]] -ne 0x5b -or
    $current[$differences[0]] -ne 0 -or $current[$differences[1]] -ne 0) {
    throw 'Other changes detected; refusing to overwrite this assembly.'
}
Copy-Item -LiteralPath $backup -Destination $target -Force
Write-Output 'Original assembly restored.'
