"""Merge Nix-owned preferences into Herdr's writable settings, preserving the rest."""

import json
import os
from pathlib import Path
import sys
import tempfile


def merge(source, target):
    managed = json.loads(source.read_text())
    settings = json.loads(target.read_text()) if target.exists() else {}
    settings.update(managed)
    text = json.dumps(settings, indent=2) + "\n"
    if target.exists() and not target.is_symlink() and target.read_text() == text:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    # Replace atomically: the running app must never see half-written JSON, and
    # an old symlink must not make us write through into its source/store path.
    fd, temporary = tempfile.mkstemp(prefix=".settings-", dir=target.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(text)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    merge(*map(Path, sys.argv[1:]))
