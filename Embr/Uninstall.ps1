$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;$dll=Join-Path $root 'FireProject_Data\Managed\Scripts.dll';$bak="$dll.embr-smooth-motion.bak"
if(!(Test-Path $bak)){throw "Backup not found: $bak"};Copy-Item $bak $dll -Force;Write-Host 'All Embr mods removed; original Scripts.dll restored.'
