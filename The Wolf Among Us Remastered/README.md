# The Wolf Among Us Remastered - Ultrawide Fix

An executable patch that removes the game's forced 16:9 rendering restriction and exposes the resolutions reported by your display, including **3440 x 1440**.

## What it changes

- Bypasses the hardcoded resolution whitelist in the graphics menu.
- Disables the scripted forced 16:9 render target.
- Uses the actual screen width-to-height ratio for the aspect ratio.
- Preserves overlay sprite proportions (including the loading wheel and save icons) by scaling their widths from screen height. Sprite positions and full-screen backgrounds are unchanged.

The patcher backs up the executable before changing it. It does not modify saved preferences or save games. Select your resolution through the game's graphics menu after installing.

## Requirements

- Windows and an existing installation of The Wolf Among Us Remastered.
- Python 3.9 or newer. No third-party Python packages are required.
- The exact supported executable build (identified by SHA-256 below).

## Install

Close the game. Download or clone this repository, open a terminal in its folder, and replace `C:\Games\The Wolf Among Us Remastered` in these commands with your installation folder.

Check compatibility without changing files:

```powershell
py ultrawide.py "C:\Games\The Wolf Among Us Remastered" --dry-run
```

Apply the patch:

```powershell
py ultrawide.py "C:\Games\The Wolf Among Us Remastered"
```

Start the game normally. Open **Settings > Graphics**, select **3440 x 1440** (or your display's native resolution), and apply it. The display must report the resolution for it to appear in the menu.

If your Python command is `python` instead of `py`, use `python` in the commands above. Your account needs write access to the game folder.

## Uninstall

Close the game, then run:

```powershell
py ultrawide.py "C:\Games\The Wolf Among Us Remastered" --restore
```

The original executable is restored from `.ultrawide-backup` inside the game folder. Keep that folder if you want to uninstall using this command. Display settings remain as you selected them.

## Compatibility and verification

Only the following executable is supported:

| Executable state | SHA-256 |
| --- | --- |
| Original | `e8cedcf34066760e480689d44964dc5596f5585c77a19a2627786a8163a65616` |
| Patched (with overlay correction) | `3605a4769af8c31247c0196f615f7df9d0e85d414b5433ed0b56b150fee94867` |
| Earlier patch (automatically upgraded) | `5a577f5c435fba7a0c98546b4ac67277f0268956274d2ce98a141a0075cd108c` |

The patcher verifies the complete executable hash, the bytes at every patch location, the resulting hash, and its backup. Running it again on the patched executable makes no further changes. Unknown or updated executables are refused.

The game reached the title screen at 3440 x 1440 during local testing. Gameplay, cutscenes, and other aspect ratios have not been fully verified. The patcher's apply/restore behavior was also checked against a disposable copy of the supported executable.

The overlay correction's machine code was checked in a CPU emulator at 1920 x 1080, 2560 x 1440, 3440 x 1440, 5120 x 1440, and 2560 x 1600, including register and flag preservation. At 3440 x 1440, sprites use a 2560-pixel reference width, matching the height-based 16:9 canvas. In-game visual verification of this correction is pending. This change targets native overlay sprites; it does not rework every menu or scene-based UI layout.

Steam updates or **Verify integrity of game files** may replace the patched executable. An updated build must be inspected before it can be supported; do not reuse these offsets blindly.

## Patch details

| File offset | Original bytes | Patched bytes | Purpose |
| --- | --- | --- | --- |
| `0x81721E` | `72 0D` | `EB 0D` | Accept display modes without the fixed whitelist. |
| `0x818485` | `B1 01` | `31 C9` | Disable the forced aspect render target. |
| `0x81848C` | `F3 0F 10 05 A8 29 BE 00` | `E8 DF BA A9 FF 90 90 90` | Get the actual screen aspect ratio instead of loading 16:9. |
| `0x8807E4` | Screen-width load and conversion (12 bytes) | Jump to the sprite correction, followed by padding | Use screen height times 16/9 as the sprite width reference. |
| `0x2F2FB0` | Unused `CC` padding (25 bytes) | Height-based sprite scaling and return jump | Preserve sprite proportions without changing their normalized positions. |

This repository contains patch source and documentation only. Game executables, assets, personal settings, and backups are not included.
