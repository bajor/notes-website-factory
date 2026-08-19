import { writeFileSync } from "node:fs";

type PdfObject = readonly [number, Buffer];

export function writeOnePagePdf(path: string): void {
  const stream = Buffer.from("BT /F1 18 Tf 72 300 Td (Freeform notes) Tj ET\n0 0 1 rg 72 190 180 60 re f\n");
  writePdf(path, [
    object(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    object(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    object(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 500 400] /CropBox [40 50 460 370] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R /Annots 6 0 R >>"),
    object(4, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    [5, Buffer.concat([Buffer.from(`<< /Length ${stream.length} >>\nstream\n`), stream, Buffer.from("endstream")])],
    object(6, "[7 0 R 10 0 R]"),
    object(7, "<< /Type /Annot /Subtype /Link /Rect [72 190 252 250] /Border [0 0 0] /A 8 0 R >>"),
    object(8, "<< /S /URI /URI 9 0 R >>"),
    object(9, "(https://www.youtube.com/watch?v=dQw4w9WgXcQ)"),
    object(10, "<< /Type /Annot /Subtype /Link /Rect [72 120 252 170] /Border [0 0 0] /A << /S /URI /URI (https://example.com/notes) >> >>"),
  ]);
}

export function writeTwoPagePdf(path: string): void {
  writePdf(path, [
    object(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    object(2, "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>"),
    object(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>"),
    object(4, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>"),
  ]);
}

function object(number: number, body: string): PdfObject {
  return [number, Buffer.from(body)];
}

function writePdf(path: string, objects: readonly PdfObject[]): void {
  const chunks = [Buffer.from("%PDF-1.7\n")];
  const offsets = new Map<number, number>();
  let length = chunks[0]!.length;
  for (const [number, body] of objects) {
    const chunk = Buffer.concat([Buffer.from(`${number} 0 obj\n`), body, Buffer.from("\nendobj\n")]);
    offsets.set(number, length);
    chunks.push(chunk);
    length += chunk.length;
  }
  const size = Math.max(...objects.map(([number]) => number)) + 1;
  const xref = [`xref\n0 ${size}\n`, "0000000000 65535 f \n"];
  for (let number = 1; number < size; number += 1) {
    xref.push(`${String(offsets.get(number) ?? 0).padStart(10, "0")} 00000 n \n`);
  }
  chunks.push(Buffer.from(`${xref.join("")}trailer\n<< /Size ${size} /Root 1 0 R >>\nstartxref\n${length}\n%%EOF\n`));
  writeFileSync(path, Buffer.concat(chunks));
}
