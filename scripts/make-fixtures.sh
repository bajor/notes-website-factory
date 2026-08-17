#!/usr/bin/env bash
set -euo pipefail

mkdir -p generator/tests/fixtures

python3 - <<'PY'
from pathlib import Path

def pdf(objects, root, pages, out):
    data = b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n"
    offsets = [0]
    for num, body in objects:
        offsets.append(len(data))
        data += f"{num} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(data)
    count = max(num for num, _ in objects) + 1
    data += f"xref\n0 {count}\n".encode()
    data += b"0000000000 65535 f \n"
    by_num = {num: off for num, off in zip([n for n,_ in objects], offsets[1:])}
    for i in range(1, count):
        data += f"{by_num.get(i, 0):010d} 00000 n \n".encode()
    data += f"trailer\n<< /Size {count} /Root {root} 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    Path(out).write_bytes(data)

stream = b"BT /F1 18 Tf 72 300 Td (Freeform PDF notes fixture) Tj ET\n0 0 1 rg 72 190 180 60 re f\n"
objects = [
    (1, b"<< /Type /Catalog /Pages 2 0 R >>"),
    (2, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    (3, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 320] /CropBox [0 0 420 320] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R /Annots [6 0 R 7 0 R] >>"),
    (4, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (5, f"<< /Length {len(stream)} >>\nstream\n".encode()+stream+b"endstream"),
    (6, b"<< /Type /Annot /Subtype /Link /Rect [72 190 252 250] /Border [0 0 0] /A << /S /URI /URI (https://www.youtube.com/watch?v=dQw4w9WgXcQ) >> >>"),
    (7, b"<< /Type /Annot /Subtype /Link /Rect [72 120 252 170] /Border [0 0 0] /A << /S /URI /URI (https://example.com/notes) >> >>"),
]
pdf(objects, 1, 2, "notes.pdf")
pdf(objects, 1, 2, "generator/tests/fixtures/one-page-links.pdf")

objects2 = [
    (1, b"<< /Type /Catalog /Pages 2 0 R >>"),
    (2, b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>"),
    (3, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>"),
    (4, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>"),
]
pdf(objects2, 1, 2, "generator/tests/fixtures/two-pages.pdf")
PY
