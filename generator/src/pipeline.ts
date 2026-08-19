import { mkdirSync, readdirSync, rmSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { discoverSinglePdf } from "./discovery.js";
import { boardLinks } from "./links.js";
import { buildManifest } from "./manifest.js";
import { inspectPdf } from "./pdf.js";
import { generateDeepZoom, renderPdfToPng, RENDER_DPI, TILE_SIZE } from "./render.js";

export function inspectRepository(repositoryRoot: string) {
  const pdf = discoverSinglePdf(repositoryRoot);
  const document = inspectPdf(pdf);
  return { pdf, document, links: boardLinks(document) };
}

export async function buildRepository(options: {
  repositoryRoot: string;
  outputDirectory: string;
  dpi?: number;
  tileSize?: number;
}) {
  const inspected = inspectRepository(options.repositoryRoot);
  const output = resolve(options.outputDirectory);
  rmSync(output, { recursive: true, force: true });
  mkdirSync(output, { recursive: true });

  const manifest = buildManifest(inspected.document, inspected.links);
  writeJson(join(output, "manifest.json"), manifest);
  const renderedBoard = join(output, "board.png");
  renderPdfToPng(inspected.pdf, renderedBoard, options.dpi ?? RENDER_DPI);
  const render = await generateDeepZoom(renderedBoard, output, options.tileSize ?? TILE_SIZE);
  unlinkSync(renderedBoard);
  writeJson(join(output, "board-render.json"), {
    pdfWidth: manifest.board.width,
    pdfHeight: manifest.board.height,
    renderedWidth: render.width,
    renderedHeight: render.height,
  });
  return { ...inspected, manifest, render, outputBytes: directorySize(output) };
}

function writeJson(path: string, value: unknown): void {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function directorySize(directory: string): number {
  return readdirSync(directory, { withFileTypes: true }).reduce((total, entry) => {
    const path = join(directory, entry.name);
    return total + (entry.isDirectory() ? directorySize(path) : statSync(path).size);
  }, 0);
}
