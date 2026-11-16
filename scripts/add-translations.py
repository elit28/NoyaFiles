#!/usr/bin/env python3
"""Adds French translations to Localizable.xcstrings.

Usage: scripts/add-translations.py translations.json

The JSON file maps English keys to French text. A key whose value is a list
of three strings has plural forms: [English singular, French singular,
French plural]; the English key itself is the English plural.
Keys use the String Catalog format: `%lld` for integers, `%@` for text.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "NoyaFiles" / "Resources" / "Localizable.xcstrings"


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def main() -> int:
    additions = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    for key, value in additions.items():
        if isinstance(value, list):
            en_one, fr_one, fr_other = value
            entry = {"localizations": {"en": plural(en_one, key), "fr": plural(fr_one, fr_other)}}
        else:
            entry = {"localizations": {"fr": unit(value)}}
        catalog["strings"][key] = entry
    catalog["strings"] = dict(sorted(catalog["strings"].items(), key=lambda item: item[0].lower()))
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Added or updated {len(additions)} translation(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
