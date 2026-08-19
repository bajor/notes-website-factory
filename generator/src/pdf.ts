import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import type {
  PageGeometry,
  PageRotation,
  PdfBox,
  PdfDocument,
  RawLinkAnnotation,
} from "./domain.js";

type JsonObject = Record<string, unknown>;

export function inspectPdf(path: string): PdfDocument {
  if (!existsSync(path)) throw new Error(`PDF is missing: ${path}`);
  const info = run("pdfinfo", ["-box", path]);
  const pageCount = parsePageCount(info);
  if (pageCount !== 1) {
    throw new Error(`${path} must contain exactly one page, found ${pageCount} pages`);
  }
  return {
    path,
    pageCount: 1,
    geometry: parseGeometry(info),
    rawLinks: parseQpdfAnnotations(run("qpdf", ["--warning-exit-0", "--json", path])),
    buildId: createHash("sha256").update(readFileSync(path)).digest("hex"),
  };
}

export function parsePageCount(info: string): number {
  const match = /^Pages:\s+(\d+)\s*$/m.exec(info);
  if (!match?.[1]) throw new Error("invalid PDF: missing page count");
  return Number.parseInt(match[1], 10);
}

export function parseGeometry(info: string): PageGeometry {
  const mediaBox = parseBox(info, "MediaBox");
  const cropBox = tryParseBox(info, "CropBox") ?? mediaBox;
  const rotation = parseRotation(info);
  if (cropBox.x2 <= cropBox.x1 || cropBox.y2 <= cropBox.y1) {
    throw new Error("invalid PDF page geometry");
  }
  return { mediaBox, cropBox, rotation };
}

export function parseQpdfAnnotations(json: string): RawLinkAnnotation[] {
  const root = asObject(JSON.parse(json), "qpdf root");
  const objects = objectTable(root);
  const pages = asArray(root.pages, "qpdf pages");
  const pageReference = asString(asObject(pages[0], "qpdf page").object, "qpdf page object");
  const page = asObject(objects.get(pageReference), "qpdf page dictionary");
  const references = page["/Annots"] === undefined
    ? []
    : asArray(resolve(objects, page["/Annots"]), "annotations");
  return references.flatMap((reference) => parseAnnotation(objects, reference)).sort(compareAnnotations);
}

export function run(command: string, args: readonly string[]): string {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if ((result.error as NodeJS.ErrnoException | undefined)?.code === "ENOENT") {
    throw new Error(`required command '${command}' is not installed`);
  }
  if (result.error) throw new Error(`${command} failed: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${command} failed: ${result.stderr.trim()}`);
  if (result.stderr.trim()) process.stderr.write(result.stderr);
  return result.stdout;
}

function tryParseBox(info: string, name: "MediaBox" | "CropBox"): PdfBox | null {
  const match = new RegExp(`^\\s*(?:Page\\s+1\\s+)?${name}:\\s+([-0-9.]+)\\s+([-0-9.]+)\\s+([-0-9.]+)\\s+([-0-9.]+)`, "m").exec(info);
  if (!match) return null;
  const values = match.slice(1, 5).map(Number);
  if (values.some((value) => !Number.isFinite(value))) throw new Error(`invalid PDF ${name}`);
  return { x1: values[0]!, y1: values[1]!, x2: values[2]!, y2: values[3]! };
}

function parseBox(info: string, name: "MediaBox" | "CropBox"): PdfBox {
  const box = tryParseBox(info, name);
  if (!box) throw new Error(`invalid PDF: missing ${name}`);
  return box;
}

function parseRotation(info: string): PageRotation {
  const value = Number.parseInt(/^Page rot:\s+(\d+)\s*$/m.exec(info)?.[1] ?? "0", 10);
  if (value === 0 || value === 90 || value === 180 || value === 270) return value;
  throw new Error(`invalid PDF page rotation: ${value}`);
}

function objectTable(root: JsonObject): Map<string, unknown> {
  const sections = asArray(root.qpdf, "qpdf object sections");
  const section = sections.map((value) => asObject(value, "qpdf section"))
    .find((value) => Object.keys(value).some((key) => key.startsWith("obj:")));
  if (!section) throw new Error("invalid PDF: missing qpdf object table");
  return new Map(Object.entries(section)
    .filter(([key]) => key.startsWith("obj:"))
    .map(([key, value]) => [key.slice(4), asObject(value, "qpdf object").value]));
}

function parseAnnotation(objects: Map<string, unknown>, reference: unknown): RawLinkAnnotation[] {
  const annotation = asObject(resolve(objects, reference), "annotation");
  const action = annotation["/A"] === undefined
    ? null
    : asObject(resolve(objects, annotation["/A"]), "annotation action");
  if (annotation["/Subtype"] !== "/Link" || action?.["/S"] !== "/URI") return [];
  const uri = asString(resolve(objects, action["/URI"]), "annotation URI").replace(/^u:/, "");
  const values = asArray(resolve(objects, annotation["/Rect"]), "annotation rectangle").map(asNumber);
  if (values.length !== 4) throw new Error("invalid annotation rectangle");
  return [{
    uri,
    rect: { x: values[0]!, y: values[1]!, width: values[2]! - values[0]!, height: values[3]! - values[1]! },
  }];
}

function resolve(objects: Map<string, unknown>, value: unknown): unknown {
  const seen = new Set<string>();
  let resolved = value;
  while (typeof resolved === "string" && objects.has(resolved)) {
    if (seen.has(resolved)) throw new Error(`invalid PDF: cyclic object reference ${resolved}`);
    seen.add(resolved);
    resolved = objects.get(resolved);
  }
  return resolved;
}

function compareAnnotations(left: RawLinkAnnotation, right: RawLinkAnnotation): number {
  return left.uri.localeCompare(right.uri) || left.rect.y - right.rect.y || left.rect.x - right.rect.x;
}

function asObject(value: unknown, name: string): JsonObject {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`invalid PDF: missing ${name}`);
  return value as JsonObject;
}

function asArray(value: unknown, name: string): unknown[] {
  if (!Array.isArray(value)) throw new Error(`invalid PDF: missing ${name}`);
  return value;
}

function asString(value: unknown, name: string): string {
  if (typeof value !== "string") throw new Error(`invalid PDF: missing ${name}`);
  return value;
}

function asNumber(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Error("invalid annotation rectangle");
  return value;
}
