import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { discoverSinglePdf } from "../src/discovery.js";

const directories: string[] = [];

afterEach(() => directories.splice(0).forEach((directory) => rmSync(directory, { recursive: true })));

describe("discoverSinglePdf", () => {
  it("discovers a PDF in a directory named target", () => {
    const root = temporaryDirectory();
    mkdirSync(join(root, "target"));
    writeFileSync(join(root, "target", "board.pdf"), "source");

    expect(discoverSinglePdf(root)).toBe(join(root, "target", "board.pdf"));
  });

  it("accepts an uppercase PDF extension", () => {
    const root = temporaryDirectory();
    writeFileSync(join(root, "board.PDF"), "source");

    expect(discoverSinglePdf(root)).toBe(join(root, "board.PDF"));
  });

  it("ignores PDFs in the generated site", () => {
    const root = temporaryDirectory();
    mkdirSync(join(root, "dist"));
    writeFileSync(join(root, "board.pdf"), "source");
    writeFileSync(join(root, "dist", "generated.pdf"), "generated");

    expect(discoverSinglePdf(root)).toBe(join(root, "board.pdf"));
  });

  it("ignores PDFs in dependencies", () => {
    const root = temporaryDirectory();
    mkdirSync(join(root, "node_modules"));
    writeFileSync(join(root, "board.pdf"), "source");
    writeFileSync(join(root, "node_modules", "dependency.pdf"), "dependency");

    expect(discoverSinglePdf(root)).toBe(join(root, "board.pdf"));
  });

  it("rejects a repository without a PDF", () => {
    const empty = temporaryDirectory();
    expect(() => discoverSinglePdf(empty)).toThrow("expected exactly one PDF file, found 0");
  });

  it("rejects a repository with multiple PDFs", () => {
    const multiple = temporaryDirectory();
    writeFileSync(join(multiple, "one.pdf"), "one");
    writeFileSync(join(multiple, "two.pdf"), "two");
    expect(() => discoverSinglePdf(multiple)).toThrow("expected exactly one PDF file, found 2");
  });
});

function temporaryDirectory(): string {
  const directory = mkdtempSync(join(tmpdir(), "notes-discovery-"));
  directories.push(directory);
  return directory;
}
