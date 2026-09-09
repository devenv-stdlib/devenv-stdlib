#!/usr/bin/env python3
"""Add and remove entries in a gsettings array-of-strings key, in place.

Keys like `org.gnome.shell favorite-apps` and `org.gnome.shell
enabled-extensions` hold the user's entire list. Home Manager's dconf.settings
would replace them, wiping the dock and every other extension, so the terminal
module edits them through this script instead.

    gsettings-list.py org.gnome.shell favorite-apps --add foo.desktop --remove bar.desktop
"""

import argparse
import ast
import subprocess
import sys


def read(schema, key):
    raw = subprocess.check_output(["gsettings", "get", schema, key], text=True).strip()
    # gsettings prints an empty array as the typed variant "@as []".
    raw = raw.removeprefix("@as ")
    value = ast.literal_eval(raw)
    if not isinstance(value, (list, tuple)):
        raise SystemExit(f"{schema} {key} is not an array: {raw}")
    return list(value)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema")
    parser.add_argument("key")
    parser.add_argument("--add", action="append", default=[], metavar="VALUE")
    parser.add_argument("--remove", action="append", default=[], metavar="VALUE")
    args = parser.parse_args(argv)

    current = read(args.schema, args.key)

    # Removals first so a value can be moved to the end of the list.
    updated = [value for value in current if value not in args.remove]
    for value in args.add:
        if value not in updated:
            updated.append(value)

    if updated == current:
        return 0

    formatted = "[" + ", ".join(repr(value) for value in updated) + "]"
    subprocess.check_call(["gsettings", "set", args.schema, args.key, formatted])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
