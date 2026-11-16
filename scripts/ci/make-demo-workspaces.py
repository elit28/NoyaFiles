#!/usr/bin/env python3
"""Writes two demo workspaces for the screenshots, with a smart rule that gathers invoices.

Usage: scripts/ci/make-demo-workspaces.py <home folder>

The file is the one NOYA Files keeps in Application Support. It follows the app's
Codable format: enums with values are written as {"case": {"_0": value}}.
"""
import json
import pathlib
import sys
import uuid


def main() -> int:
    home = pathlib.Path(sys.argv[1]).expanduser()
    folder = home / "Library" / "Application Support" / "NOYA Files"
    folder.mkdir(parents=True, exist_ok=True)

    invoices = str(uuid.uuid4()).upper()
    workspaces = [
        {
            "id": str(uuid.uuid4()).upper(),
            "name": "Impôts 2026",
            "summary": "Factures et justificatifs pour la déclaration",
            "color": "blue",
            "collections": [{"id": invoices, "name": "Factures"}],
            "entries": [],
            "rules": [{
                "id": str(uuid.uuid4()).upper(),
                "condition": {"nameContains": {"_0": "facture", "extensions": ["pdf"]}},
                "collectionID": invoices,
                "isEnabled": True,
                "matchCount": 0,
            }],
        },
        {
            "id": str(uuid.uuid4()).upper(),
            "name": "Freelance",
            "summary": "Devis, contrats et livrables",
            "color": "purple",
            "collections": [],
            "entries": [],
            "rules": [],
        },
    ]
    path = folder / "workspaces.json"
    path.write_text(json.dumps(workspaces, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
