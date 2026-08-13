param([ValidateSet(1,2,4,8,16,32)][int]$ResolutionDivisor = 4)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;$dll=Join-Path $root 'FireProject_Data\Managed\Scripts.dll';$bak="$dll.embr-smooth-motion.bak";$cecil=Join-Path $root '.modtools\ilspy\Mono.Cecil.dll'
if(!(Test-Path $bak)){Copy-Item $dll $bak};Add-Type -Path $cecil
$r=New-Object Mono.Cecil.DefaultAssemblyResolver;$r.AddSearchDirectory((Split-Path $dll));$p=New-Object Mono.Cecil.ReaderParameters;$p.AssemblyResolver=$r;$a=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($dll,$p)
$m=(($a.MainModule.Types|? FullName -eq 'VictimLocator').Methods|? Name -eq 'Start');$i=$m.Body.Instructions;$calls=@($i|?{$_.Operand -and $_.Operand.FullName -match 'Screen::get_(width|height)'})
if($calls.Count-ne 2){throw 'Unexpected Client Findr layout.'};foreach($c in $calls){$n=$i.IndexOf($c);if($i[$n+2].OpCode.Code-ne [Mono.Cecil.Cil.Code]::Div){throw 'Unexpected resolution calculation.'};$i[$n+1].OpCode=[Mono.Cecil.Cil.OpCodes]::Ldc_I4;$i[$n+1].Operand=$ResolutionDivisor}
$tmp="$dll.embr-smooth-motion.tmp";$a.Write($tmp);$a.Dispose();Move-Item $tmp $dll -Force;Write-Host "Client Findr installed at 1/$ResolutionDivisor dimensions."
