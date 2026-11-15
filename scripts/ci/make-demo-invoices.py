#!/usr/bin/env python3
"""Writes a few invoices as real PDFs, for the AI assistant screenshots.

Usage: scripts/ci/make-demo-invoices.py <home folder>

The invoices go to <home>/Downloads and <home>/Documents/Administratif/Factures 2026,
where the assistant looks. Two of them have unclear names, as scanners give them,
so the assistant proposes names taken from their text.
"""
import pathlib
import sys


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def write_pdf(path: pathlib.Path, lines: list[str]) -> None:
    """A one-page PDF with the lines in Helvetica, readable by PDFKit and Spotlight."""
    content = "BT /F1 13 Tf 72 770 Td 20 TL\n"
    content += "".join(f"({escape(line)}) Tj T*\n" for line in lines)
    content += "ET"
    stream = content.encode("cp1252")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
    ]
    output = b"%PDF-1.4\n"
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(output))
        output += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    table = len(output)
    output += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    output += b"".join(b"%010d 00000 n \n" % offset for offset in offsets)
    output += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, table)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(output)


def main() -> int:
    home = pathlib.Path(sys.argv[1]).expanduser()
    downloads = home / "Downloads"
    invoices = home / "Documents" / "Administratif" / "Factures 2026"

    write_pdf(downloads / "scan0012.pdf", [
        "EDF",
        "Facture n° 10-2026-4471",
        "Date : 12/10/2026",
        "Électricité, période du 01/09/2026 au 30/09/2026",
        "Montant TTC : 84,12 €",
        "Espace client : www.edf.fr - service-client@edf.fr",
    ])
    write_pdf(downloads / "document(3).pdf", [
        "Free SAS",
        "Facture du 3 septembre 2026",
        "Abonnement Freebox Pop",
        "Montant TTC : 39,99 €",
        "Votre espace abonné : https://subscribe.free.fr",
    ])
    write_pdf(downloads / "Relevé EDF juillet.pdf", [
        "EDF",
        "Facture de régularisation",
        "Relevé du 28/07/2026",
        "www.edf.fr",
    ])
    for number, date in (("118", "02/11/2026"), ("117", "05/10/2026")):
        write_pdf(invoices / f"Facture 2026-{number}.pdf", [
            "NOYA 360",
            f"Facture 2026-{number}",
            f"Date : {date}",
            "Site web et maintenance",
            "contact@noya360.fr",
        ])
    print(f"Wrote demo invoices in {downloads} and {invoices}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
