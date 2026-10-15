$ErrorActionPreference = 'Stop'
$gameData = Split-Path $PSScriptRoot -Parent
$assemblyPath = Join-Path $gameData 'Managed\Assembly-CSharp.dll'
$backupPath = Join-Path $PSScriptRoot 'Assembly-CSharp.dll.original'
$cecilPath = 'C:\Users\Atlas\.nuget\packages\microsoft.net.illink.tasks\7.0.100-1.23211.1\tools\net472\Mono.Cecil.dll'
if (Get-Process -Name IGTAPfullGame -ErrorAction SilentlyContinue) {
    throw 'Close the game before applying the patch.'
}
Add-Type -Path $cecilPath
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($assemblyPath)
try {
    $type = $assembly.MainModule.Types | Where-Object Name -eq 'AspectRatioHandler'
    $method = $type.Methods | Where-Object Name -eq 'UpdateResolution'
    if (-not $method -or $method.Body.CodeSize -ne 183) { throw 'Unrecognized game version.' }
    $rva = $method.RVA
    $instructions = @($method.Body.Instructions)
    $load = $instructions | Where-Object Offset -eq 0x6c
    $divide = $instructions | Where-Object Offset -eq 0x6d
    if ($load.OpCode.Name -eq 'nop' -and $divide.OpCode.Name -eq 'nop') {
        Write-Output 'Ultrawide patch is already installed.'
        return
    }
    if ($load.OpCode.Name -ne 'ldloc.1' -or $divide.OpCode.Name -ne 'div') {
        throw 'Unexpected aspect-ratio instructions; no files changed.'
    }
} finally { $assembly.Dispose() }

# Map the method RVA to its PE file offset. Preserve all metadata and other code.
$bytes = [IO.File]::ReadAllBytes($assemblyPath)
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
$sectionCount = [BitConverter]::ToUInt16($bytes, $pe + 6)
$optionalSize = [BitConverter]::ToUInt16($bytes, $pe + 20)
$sectionTable = $pe + 24 + $optionalSize
$methodOffset = -1
for ($i = 0; $i -lt $sectionCount; $i++) {
    $section = $sectionTable + 40 * $i
    $virtualAddress = [BitConverter]::ToUInt32($bytes, $section + 12)
    $rawSize = [BitConverter]::ToUInt32($bytes, $section + 16)
    $rawOffset = [BitConverter]::ToUInt32($bytes, $section + 20)
    if ($rva -ge $virtualAddress -and $rva -lt ($virtualAddress + $rawSize)) {
        $methodOffset = [int]($rawOffset + $rva - $virtualAddress)
        break
    }
}
if ($methodOffset -lt 0 -or ($bytes[$methodOffset] -band 3) -ne 3) {
    throw 'Unrecognized method header.'
}
$headerSize = ([BitConverter]::ToUInt16($bytes, $methodOffset) -shr 12) * 4
$patchOffset = $methodOffset + $headerSize + 0x6c
if ($bytes[$patchOffset] -ne 7 -or $bytes[$patchOffset + 1] -ne 0x5b) {
    throw 'Unexpected patch bytes.'
}
if (Test-Path -LiteralPath $backupPath) {
    if ((Get-FileHash $backupPath).Hash -ne (Get-FileHash $assemblyPath).Hash) {
        throw 'Existing backup differs from this game version; preserve it before reapplying.'
    }
} else {
    Copy-Item -LiteralPath $assemblyPath -Destination $backupPath
}
# The wide-screen branch now uses viewport width 1 instead of 1 / aspectScale.
# Its existing code sets x=0, y=0, height=1. Narrow-screen handling is unchanged.
$bytes[$patchOffset] = 0
$bytes[$patchOffset + 1] = 0
[IO.File]::WriteAllBytes($assemblyPath, $bytes)
$verify = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($assemblyPath)
try {
    $patched = ($verify.MainModule.Types | Where-Object Name -eq 'AspectRatioHandler').Methods |
        Where-Object Name -eq 'UpdateResolution'
    $nops = @($patched.Body.Instructions | Where-Object { $_.Offset -in 0x6c,0x6d -and $_.OpCode.Name -eq 'nop' })
    if ($nops.Count -ne 2) { throw 'Patch verification failed.' }
} finally { $verify.Dispose() }
Write-Output "Ultrawide patch installed and verified at file offset $patchOffset. Original saved to $backupPath"
