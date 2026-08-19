import { boardSize, type BoardLink, type PdfDocument, type SiteManifest } from "./domain.js";

export function buildManifest(document: PdfDocument, links: readonly BoardLink[]): SiteManifest {
  const manifest: SiteManifest = {
    version: 1,
    buildId: document.buildId,
    board: boardSize(document.geometry),
    links: [...links].sort(compareLinks),
  };
  validateManifest(manifest);
  return manifest;
}

function validateManifest(manifest: SiteManifest): void {
  if (manifest.board.width <= 0 || manifest.board.height <= 0) {
    throw new Error("manifest board dimensions must be positive");
  }
  for (const link of manifest.links) validateLink(manifest, link);
}

function validateLink(manifest: SiteManifest, link: BoardLink): void {
  if (link.width <= 0 || link.height <= 0) {
    throw new Error("manifest link rectangles must be positive");
  }
  const outside = link.x < 0 || link.y < 0
    || link.x + link.width > manifest.board.width + 0.5
    || link.y + link.height > manifest.board.height + 0.5;
  if (outside) throw new Error("manifest link rectangle is outside board bounds");
}

function compareLinks(left: BoardLink, right: BoardLink): number {
  return left.y - right.y
    || left.x - right.x
    || left.width - right.width
    || left.height - right.height
    || linkKey(left).localeCompare(linkKey(right));
}

function linkKey(link: BoardLink): string {
  return link.kind === "youtube" ? `youtube:${link.videoId}` : `url:${link.url}`;
}
