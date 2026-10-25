"""Keep Streamrip credentials writable while applying checkout preferences."""

from collections.abc import MutableMapping
from pathlib import Path
import sys

import tomlkit


def merge(target, source):
    for key, value in source.items():
        if isinstance(value, MutableMapping) and isinstance(target.get(key), MutableMapping):
            merge(target[key], value)
        else:
            target[key] = value


def main():
    template, preferences, target = map(Path, sys.argv[1:])
    config = tomlkit.parse(template.read_text())
    if target.exists():
        merge(config, tomlkit.parse(target.read_text()))
    managed = preferences.read_text().replace("@HOME@", str(Path.home()))
    managed = managed.replace("@CONFIG@", str(target.parent))
    merge(config, tomlkit.parse(managed))
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink():
        target.unlink()
    target.touch(mode=0o600, exist_ok=True)
    target.chmod(0o600)
    target.write_text(tomlkit.dumps(config))


if __name__ == "__main__":
    main()
