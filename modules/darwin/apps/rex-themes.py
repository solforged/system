"""Update Solforge's Rex themes, preserving themes with other IDs."""
import json
import plistlib
import subprocess
import sys


def merge_themes(existing, incoming):
    ids = {theme["id"] for theme in incoming}
    return [theme for theme in existing if theme["id"] not in ids] + incoming


def main(path):
    with open(path) as source:
        incoming = json.load(source)
    result = subprocess.run(
        ["/usr/bin/defaults", "export", "com.superlogical.rex", "-"],
        capture_output=True,
    )
    if result.returncode:
        # A new installation has no preferences domain yet. Don't conceal
        # permission errors or malformed existing data.
        if b"does not exist" not in result.stderr:
            raise RuntimeError(result.stderr.decode())
        existing = []
    else:
        prefs = plistlib.loads(result.stdout)
        existing = json.loads(prefs.get("Workspace.customThemes", b"[]"))
    merged = merge_themes(existing, incoming)
    if merged != existing:
        data = json.dumps(merged, separators=(",", ":")).encode().hex()
        subprocess.run(
            ["/usr/bin/defaults", "write", "com.superlogical.rex",
             "Workspace.customThemes", "-data", data],
            check=True,
        )
        print("Updated Rex themes; relaunch Rex to load them.")


if __name__ == "__main__":
    main(sys.argv[1])
