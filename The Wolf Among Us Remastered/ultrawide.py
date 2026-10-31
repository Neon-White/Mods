"""Apply or restore the ultrawide patch for one verified game build."""

import argparse
import hashlib
import os
from pathlib import Path
import tempfile

EXECUTABLE = "TheWolfAmongUsRemastered.exe"
ORIGINAL_SHA256 = "e8cedcf34066760e480689d44964dc5596f5585c77a19a2627786a8163a65616"
PATCHED_SHA256 = "5a577f5c435fba7a0c98546b4ac67277f0268956274d2ce98a141a0075cd108c"
PATCHES = (
    (0x81721E, bytes.fromhex("720d"), bytes.fromhex("eb0d")),
    (0x818485, bytes.fromhex("b101"), bytes.fromhex("31c9")),
    (0x81848C, bytes.fromhex("f30f1005a829be00"), bytes.fromhex("e8dfbaa9ff909090")),
)


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
        if current_hash != PATCHED_SHA256:
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
