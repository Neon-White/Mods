# Embr Mod Manager

This folder contains three modular patches for the Windows Mono build of Embr,
plus an interactive manager that can install any selection of them.

## Folder placement

Place this entire `Embr` mod folder directly inside the game's installation
folder. Do not place only the individual scripts there.

The expected layout is:

```text
Embr game folder\
|-- FireProject.exe
|-- FireProject_Data\
|   `-- Managed\
|       `-- Scripts.dll
|-- .modtools\
|   `-- ilspy\
|       `-- Mono.Cecil.dll
`-- Embr\
    |-- EmbrModInstaller.ps1
    |-- Launch Mod Manager.bat
    `-- README.md
```

The scripts use their own location to find the parent game folder and then locate
`FireProject_Data\Managed\Scripts.dll`. They will not find the game assembly if
the `Embr` mod folder is placed elsewhere.

## Included mods

### Smooth movement

Fixes first-person movement stutter at frame rates above the physics update rate.
It enables Rigidbody interpolation and changes player-root yaw to use
`Rigidbody.MoveRotation`, while camera pitch remains render-rate.

This does not cap rendering, change gameplay speed, or alter Unity's physics
timestep.

### Higher-resolution Client Findr

The stock Client Findr camera renders at only `1/32` of the screen dimensions.
This mod uses `1/4` by default. Lower divisors are sharper and require more GPU
work; higher divisors are faster and less sharp.

### Ultrawide Windowed Fullscreen

Changes the existing Windowed Fullscreen option to 3440x1440 by default. Custom
dimensions can be supplied through the interactive prompts or command line.

## Interactive installation

Close Embr before installing or uninstalling mods.

Double-click `Launch Mod Manager.bat`. The menu provides these choices:

1. Install all mods
2. Choose individual mods
3. Uninstall all mods
4. Exit without making changes

When applicable, it asks for the Client Findr quality divisor and borderless
resolution. Press Enter at a prompt to accept its displayed default.

The manager can also be started from the Embr directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\Embr\EmbrModInstaller.ps1
```

## Command-line usage

Install every mod with its defaults:

```powershell
.\Embr\EmbrModInstaller.ps1 -Mods All
```

Install selected mods:

```powershell
.\Embr\EmbrModInstaller.ps1 -Mods Movement,ClientFindr
```

Available mod names are `Movement`, `ClientFindr`, and `Ultrawide`.

Install all mods with custom settings:

```powershell
.\Embr\EmbrModInstaller.ps1 `
    -Mods All `
    -ClientFindrResolutionDivisor 2 `
    -BorderlessWidth 3440 `
    -BorderlessHeight 1440
```

Valid Client Findr divisors are `1`, `2`, `4`, `8`, `16`, and `32`.

Uninstall all mods:

```powershell
.\Embr\EmbrModInstaller.ps1 -Action Uninstall
```

If local PowerShell execution policy blocks the shorter examples, prefix them
with `powershell -ExecutionPolicy Bypass -File` as shown above.

## Modular installers

Each mod can be installed without the manager:

```powershell
.\Embr\PatchSmoothMovement.ps1
.\Embr\PatchClientFindr.ps1 -ResolutionDivisor 4
.\Embr\PatchUltrawideBorderless.ps1 -Width 3440 -Height 1440
```

`Uninstall.ps1` restores the original assembly and therefore removes every mod,
not just one selected patch.

## Backup and updates

The first patch installed creates this backup:

```text
FireProject_Data\Managed\Scripts.dll.embr-smooth-motion.bak
```

Uninstallation restores that file over `Scripts.dll`. Do not delete it if you
want to use the included uninstaller.

Steam verification or a game update may replace the patched assembly. After an
update, remove the old backup so the next installation records the new unmodified
game assembly, then apply the desired mods again.

## Requirements

- The Windows Mono version of Embr represented by the current `Scripts.dll`.
- `Mono.Cecil.dll` at `.modtools\ilspy\Mono.Cecil.dll` in the Embr directory.
- The game must be closed while its managed assembly is modified.

The patch scripts validate the expected code layout and stop with an error when
the installed game assembly is incompatible.
