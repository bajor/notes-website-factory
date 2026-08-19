import type { BoardLink, PdfDocument } from "./domain.js";
import { pdfToBoardCoordinates } from "./geometry.js";

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;

type ClassifiedLink =
  | Readonly<{ kind: "youtube"; videoId: string }>
  | Readonly<{ kind: "externalUrl"; url: string }>;

export function parseYoutubeUrl(raw: string): string | null {
  const url = parseHttpUrl(raw);
  if (!url) return null;

  const host = url.hostname.toLowerCase();
  const segments = url.pathname.split("/").filter(Boolean);
  let candidate: string | null = null;
  if (["youtube.com", "www.youtube.com", "m.youtube.com"].includes(host)) {
    candidate = youtubeComId(url, segments);
  } else if (host === "youtu.be") {
    candidate = segments[0] ?? null;
  }
  return candidate && YOUTUBE_ID.test(candidate) ? candidate : null;
}

export function boardLinks(document: PdfDocument): BoardLink[] {
  return document.rawLinks.map((annotation) => {
    const rect = pdfToBoardCoordinates(annotation.rect, document.geometry);
    if (!rect) throw new Error("invalid annotation rectangle");
    const link = classifyUrl(annotation.uri);
    if (!link) throw new Error(`unsafe or unsupported URL: ${annotation.uri}`);
    return { ...rounded(rect), ...link };
  });
}

function classifyUrl(raw: string): ClassifiedLink | null {
  const videoId = parseYoutubeUrl(raw);
  if (videoId) return { kind: "youtube", videoId };
  const url = parseHttpUrl(raw);
  return url ? { kind: "externalUrl", url: url.href } : null;
}

function youtubeComId(url: URL, segments: readonly string[]): string | null {
  if (url.pathname === "/watch") return url.searchParams.get("v");
  return segments.length >= 2 && (segments[0] === "shorts" || segments[0] === "embed")
    ? segments[1] ?? null
    : null;
}

function parseHttpUrl(raw: string): URL | null {
  try {
    const url = new URL(raw);
    return url.protocol === "http:" || url.protocol === "https:" ? url : null;
  } catch {
    return null;
  }
}

function rounded(rect: Readonly<{ x: number; y: number; width: number; height: number }>) {
  const round = (value: number) => Math.round(value * 1000) / 1000;
  return { x: round(rect.x), y: round(rect.y), width: round(rect.width), height: round(rect.height) };
}
