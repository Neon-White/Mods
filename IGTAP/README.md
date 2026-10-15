# IGTAP ultrawide patch

Removes the pillarboxing imposed by `AspectRatioHandler.UpdateResolution` on displays wider than 16:9. The camera uses the full viewport and retains its existing orthographic size, showing more of the world horizontally. It adapts to the actual resolution, including 3440x1440. The original handling of narrower displays is preserved.

Enable Fullscreen in the game's settings to use the monitor's native resolution.

Only two instruction bytes in `Managed/Assembly-CSharp.dll` are modified: `ldloc.1; div` becomes `nop; nop` in the wide-screen viewport-width calculation. All other assembly bytes remain unchanged. Saves and settings are untouched.

The original assembly is stored beside this file as `Assembly-CSharp.dll.original`. To undo, close the game and run `powershell -ExecutionPolicy Bypass -File .\Ultrawide\restore.ps1` from the game data directory. Steam file verification can also restore the installed game files.

Game updates or Steam verification may remove the patch. `apply.ps1` checks the expected method structure before patching and uses the locally installed Mono.Cecil library at the path specified in the script. It refuses to overwrite a backup from a different game version.

Validation: patched IL is parsed with Mono.Cecil and the assembly is compared byte-for-byte against its backup. Live rendering and UI layout still require an in-game check.
