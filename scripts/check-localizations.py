#!/usr/bin/env python3
"""Checks that every user-facing string in the app has a French translation.

It scans the Swift sources for string literals passed to localizing APIs
(Text, Button, String(localized:), …) and compares them with the keys of
Localizable.xcstrings. Interpolations such as \\(count) and format
specifiers such as %lld are treated as the same placeholder.

Usage: scripts/check-localizations.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "NoyaFiles"
CATALOG = SOURCES / "Resources" / "Localizable.xcstrings"
LANGUAGE = "fr"

LITERAL = r'"((?:[^"\\\n]|\\.)*)"'
CALLS = (
    r"String\(localized:\s*",
    r"(?<![\w.])Text\(",
    r"Button\(",
    r"Label\(",
    r"Section\(",
    r"\.help\(",
    r"TableColumn\(",
    r"Picker\(",
    r"Toggle\(",
    r"ContentUnavailableView\(\s*",
    r"CommandMenu\(",
    r"PanelSectionTitle\(",
    r"\.alert\(\s*",
    r"TextField\(",
    r"LabeledContent\(",
    r"\.confirmationDialog\(\s*",
    r"(?<![\w.])fact\(",
    r"Entry\(id: \"[^\"]*\", title: ",
    r"LocalizedStringKey\(",
    # Literals passed to the labeled parameters of the app's own views, such as `Card(title: "Trash")`.
    r"(?<![\w.])(?:title|empty|message|subtitle|caption|prompt|placeholder|headline):\s*",
)
CALL_PATTERN = re.compile(r"(?:%s)%s" % ("|".join(CALLS), LITERAL))
# Ternaries typed as LocalizedStringKey: `flag ? "Hide X" : "Show X"`.
KEY_TERNARY = re.compile(r"LocalizedStringKey\s*\{\s*[^\n]*\?\s*%s\s*:\s*%s" % (LITERAL, LITERAL))
PLACEHOLDER = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)|%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f)")


def normalize(text: str) -> str:
    return PLACEHOLDER.sub("#", text)


def source_strings() -> dict[str, pathlib.Path]:
    found: dict[str, pathlib.Path] = {}
    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in CALL_PATTERN.finditer(text):
            found.setdefault(match.group(1), path)
        for match in KEY_TERNARY.finditer(text):
            found.setdefault(match.group(1), path)
            found.setdefault(match.group(2), path)
    return found


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    translated = {
        normalize(key)
        for key, entry in catalog["strings"].items()
        if LANGUAGE in entry.get("localizations", {}) or entry.get("shouldTranslate") is False
    }
    missing = sorted(
        (str(path.relative_to(ROOT)), literal)
        for literal, path in source_strings().items()
        if literal.strip() and normalize(literal) not in translated
    )
    for path, literal in missing:
        print(f"{path}: missing '{LANGUAGE}' translation for \"{literal}\"")
    if missing:
        print(f"\n{len(missing)} string(s) need a translation in {CATALOG.relative_to(ROOT)}.")
        return 1
    print(f"All user-facing strings have a '{LANGUAGE}' translation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
