import { statSync } from "node:fs";
import { resolve } from "node:path";
import { boardSize } from "./domain.js";
import { displayPath } from "./discovery.js";
import { buildRepository, inspectRepository } from "./pipeline.js";

async function main(): Promise<void> {
  const command = process.argv[2];
  const repositoryRoot = resolve(option("--root") ?? process.cwd());
  if (command === "inspect") {
    printInspection(repositoryRoot);
    return;
  }
  if (command === "build") {
    await build(repositoryRoot, resolve(option("--dist") ?? `${repositoryRoot}/dist`));
    return;
  }
  throw new Error("usage: cli.ts inspect|build [--root PATH] [--dist PATH]");
}

function printInspection(repositoryRoot: string): void {
  const result = inspectRepository(repositoryRoot);
  const size = boardSize(result.document.geometry);
  const youtube = result.links.filter((link) => link.kind === "youtube").length;
  console.log(`File: ${displayPath(repositoryRoot, result.pdf)}`);
  console.log(`Pages: 1`);
  console.log(`Board: ${size.width} x ${size.height} pt`);
  console.log(`URI annotations: ${result.links.length}`);
  console.log(`YouTube annotations: ${youtube}`);
}

async function build(repositoryRoot: string, outputDirectory: string): Promise<void> {
  const result = await buildRepository({ repositoryRoot, outputDirectory });
  const inputBytes = statSync(result.pdf).size;
  const youtube = result.links.filter((link) => link.kind === "youtube").length;
  console.log(`Input PDF:           ${mib(inputBytes)} MiB`);
  console.log(`Board:               ${result.manifest.board.width} x ${result.manifest.board.height} pt`);
  console.log(`URI annotations:     ${result.links.length}`);
  console.log(`YouTube annotations: ${youtube}`);
  console.log(`Deep Zoom levels:    ${result.render.levels}`);
  console.log(`Output:              ${mib(result.outputBytes)} MiB`);
}

function option(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  if (index === -1) return undefined;
  const value = process.argv[index + 1];
  if (!value || value.startsWith("--")) throw new Error(`${name} requires a value`);
  return value;
}

function mib(bytes: number): string {
  return (bytes / 1024 / 1024).toFixed(1);
}

main().catch((error: unknown) => {
  console.error(`ERROR: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
