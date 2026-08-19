import { readdirSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const IGNORED_DIRECTORIES = new Set([".git", "dist", "node_modules"]);

export function discoverSinglePdf(repositoryRoot: string): string {
  const root = resolve(repositoryRoot);
  const pdfs = collectPdfs(root);
  if (pdfs.length !== 1) {
    throw new Error(`expected exactly one PDF file, found ${pdfs.length}`);
  }
  return pdfs[0]!;
}

function collectPdfs(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => collectEntry(directory, entry.name, entry.isDirectory(), entry.isFile()))
    .sort((left, right) => left.localeCompare(right));
}

function collectEntry(directory: string, name: string, isDirectory: boolean, isFile: boolean): string[] {
  const path = join(directory, name);
  if (isDirectory) {
    return IGNORED_DIRECTORIES.has(name) ? [] : collectPdfs(path);
  }
  return isFile && name.toLowerCase().endsWith(".pdf") ? [path] : [];
}

export function displayPath(repositoryRoot: string, path: string): string {
  return relative(resolve(repositoryRoot), path) || path;
}
