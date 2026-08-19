import { rmSync } from "node:fs";
import { extname, join } from "node:path";
import sharp from "sharp";
import { run } from "./pdf.js";

export const RENDER_DPI = 180;
export const TILE_SIZE = 256;

export function renderPdfToPng(pdf: string, output: string, dpi = RENDER_DPI): void {
  const stem = output.slice(0, -extname(output).length);
  run("pdftoppm", ["-singlefile", "-png", "-cropbox", "-r", String(dpi), pdf, stem]);
}

export async function generateDeepZoom(source: string, outputDirectory: string, tileSize = TILE_SIZE) {
  const metadata = await sharp(source).metadata();
  if (!metadata.width || !metadata.height) throw new Error("rendered board has invalid dimensions");
  await sharp(source)
    .png({ compressionLevel: 6 })
    .tile({ size: tileSize, overlap: 0, layout: "dz", depth: "onepixel" })
    .toFile(join(outputDirectory, "board.dz"));
  rmSync(join(outputDirectory, "board_files", "vips-properties.xml"), { force: true });
  return {
    width: metadata.width,
    height: metadata.height,
    levels: Math.ceil(Math.log2(Math.max(metadata.width, metadata.height))) + 1,
  };
}
