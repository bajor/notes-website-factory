import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { inspectPdf } from "../src/pdf.js";
import { writeTwoPagePdf } from "./pdf-fixture.js";

let directory: string | undefined;

afterEach(() => {
  if (directory) rmSync(directory, { recursive: true });
  directory = undefined;
});

describe("inspectPdf integration", () => {
  it("rejects a PDF containing more than one page", () => {
    directory = mkdtempSync(join(tmpdir(), "notes-pdf-"));
    const pdf = join(directory, "board.pdf");
    writeTwoPagePdf(pdf);
    expect(() => inspectPdf(pdf)).toThrow("must contain exactly one page, found 2 pages");
  });
});
