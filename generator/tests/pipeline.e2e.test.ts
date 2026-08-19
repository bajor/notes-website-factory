import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { buildRepository } from "../src/pipeline.js";
import { writeOnePagePdf } from "./pdf-fixture.js";

let root: string;
let output: string;
let result: Awaited<ReturnType<typeof buildRepository>>;

beforeAll(async () => {
  root = mkdtempSync(join(tmpdir(), "notes-build-"));
  output = join(root, "dist");
  writeOnePagePdf(join(root, "freeform-export.pdf"));
  result = await buildRepository({ repositoryRoot: root, outputDirectory: output });
});

afterAll(() => rmSync(root, { recursive: true }));

describe("buildRepository end to end", () => {
  it("writes a YouTube link from its PDF annotation", () => {
    expect(result.manifest.links).toContainEqual(expect.objectContaining({
      kind: "youtube",
      videoId: "dQw4w9WgXcQ",
    }));
  });

  it("writes an external link from its PDF annotation", () => {
    expect(result.manifest.links).toContainEqual(expect.objectContaining({
      kind: "externalUrl",
      url: "https://example.com/notes",
    }));
  });

  it("renders the CropBox at production resolution", () => {
    expect(readFileSync(join(output, "board.dzi"), "utf8"))
      .toMatch(/Height="800"[\s\S]*Width="1050"/);
  });

  it("writes the full-resolution Deep Zoom tile level", () => {
    expect(existsSync(join(output, "board_files", "11", "0_0.png"))).toBe(true);
  });

  it("omits timestamped libvips metadata", () => {
    expect(existsSync(join(output, "board_files", "vips-properties.xml"))).toBe(false);
  });
});
