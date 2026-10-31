"""Apply or restore the ultrawide patch for one verified game build."""

import argparse
import hashlib
import os
from pathlib import Path
import struct
import tempfile

EXECUTABLE = "TheWolfAmongUsRemastered.exe"
ORIGINAL_SHA256 = "e8cedcf34066760e480689d44964dc5596f5585c77a19a2627786a8163a65616"
LEGACY_SHA256 = "5a577f5c435fba7a0c98546b4ac67277f0268956274d2ce98a141a0075cd108c"
# Sprite widths use a 16:9 reference canvas. Scale them from screen height
# instead of screen width; positions and full-screen backgrounds stay native.
SPRITE_SITE = 0x8807E4
SPRITE_CAVE = 0x2F2FB0
TEXT_RVA_DELTA = 0xC00


def relative_jump(source, destination):
    return b"\xe9" + struct.pack("<i", destination - source - 5)


def sprite_code():
    # movd xmm0,[rsp+0xa0]; cvtdq2ps xmm0,xmm0
    code = bytes.fromhex("660f6e8424a00000000f5bc0")
    # mulss xmm0,[rip+reference_aspect] (16/9)
    reference_aspect_rva = 0x13FBA3C
    instruction_end_rva = SPRITE_CAVE + TEXT_RVA_DELTA + len(code) + 8
    code += bytes.fromhex("f30f5905") + struct.pack("<i", reference_aspect_rva - instruction_end_rva)
    code += relative_jump(SPRITE_CAVE + len(code), SPRITE_SITE + 12)
    return code


PATCHES = (
    (0x81721E, bytes.fromhex("720d"), bytes.fromhex("eb0d")),
    (0x818485, bytes.fromhex("b101"), bytes.fromhex("31c9")),
    (0x81848C, bytes.fromhex("f30f1005a829be00"), bytes.fromhex("e8dfbaa9ff909090")),
    (SPRITE_SITE, bytes.fromhex("660f6e84249c0000000f5bc0"),
     relative_jump(SPRITE_SITE, SPRITE_CAVE) + b"\x90" * 7),
    (SPRITE_CAVE, b"\xcc" * len(sprite_code()), sprite_code()),
)

PATCHED_SHA256 = "3605a4769af8c31247c0196f615f7df9d0e85d414b5433ed0b56b150fee94867"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_file(target, data):
    """Stage beside the executable, then replace it in one filesystem operation."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".ultrawide-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if temporary.read_bytes() != data:
            raise ValueError("Staged file verification failed.")
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def run(game_dir, restore=False, dry_run=False):
    target = Path(game_dir).resolve() / EXECUTABLE
    data = target.read_bytes()
    current_hash = digest(data)
    backup = target.parent / ".ultrawide-backup" / (EXECUTABLE + ".original")

    if restore:
        if current_hash == ORIGINAL_SHA256:
            return "The executable is already original."
        if current_hash not in (PATCHED_SHA256, LEGACY_SHA256):
            raise ValueError("Unknown executable build. Restore refused to avoid replacing an updated game.")
        original = backup.read_bytes()
        if digest(original) != ORIGINAL_SHA256:
            raise ValueError("Backup verification failed; the executable was not changed.")
        if dry_run:
            return "Restore check passed. No files changed."
        replace_file(target, original)
        return "Original executable restored. Display preferences were not changed."

    if current_hash == PATCHED_SHA256:
        return "The ultrawide patch is already installed."
    if current_hash == LEGACY_SHA256:
        original = bytearray(data)
        for offset, old, new in PATCHES[:3]:
            if original[offset:offset + len(new)] != new:
                raise ValueError("Previous patch verification failed. No files changed.")
            original[offset:offset + len(old)] = old
        data = bytes(original)
        current_hash = digest(data)
    if current_hash != ORIGINAL_SHA256:
        raise ValueError("Unsupported executable SHA-256. No files changed.")

    patched = bytearray(data)
    for offset, old, new in PATCHES:
        if len(old) != len(new) or data[offset:offset + len(old)] != old:
            raise ValueError(f"Unexpected bytes at {offset:#x}. No files changed.")
        patched[offset:offset + len(old)] = new
    patched = bytes(patched)
    if digest(patched) != PATCHED_SHA256:
        raise ValueError("Patched executable verification failed. No files changed.")
    if backup.exists() and backup.read_bytes() != data:
        raise ValueError("An existing backup does not match the original. No files changed.")
    if dry_run:
        return "Compatibility check passed. No files changed."

    backup.parent.mkdir(exist_ok=True)
    if not backup.exists():
        with backup.open("xb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    if backup.read_bytes() != data:
        raise ValueError("Backup verification failed; the executable was not changed.")
    replace_file(target, patched)
    return "Ultrawide patch installed. Select your native resolution in Settings > Graphics."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game_dir", type=Path, help="Folder containing the game executable")
    parser.add_argument("--restore", action="store_true", help="Restore the verified original executable")
    parser.add_argument("--dry-run", action="store_true", help="Check compatibility without writing files")
    args = parser.parse_args()
    try:
        print(run(args.game_dir, restore=args.restore, dry_run=args.dry_run))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Error: {error}\nClose the game before applying or restoring a patch.\n")


if __name__ == "__main__":
    main()
