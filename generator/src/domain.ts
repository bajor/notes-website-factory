export type Rect = Readonly<{
  x: number;
  y: number;
  width: number;
  height: number;
}>;

export type PdfBox = Readonly<{
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}>;

export type PageRotation = 0 | 90 | 180 | 270;

export type PageGeometry = Readonly<{
  mediaBox: PdfBox;
  cropBox: PdfBox;
  rotation: PageRotation;
}>;

export type RawLinkAnnotation = Readonly<{
  rect: Rect;
  uri: string;
}>;

type BoardRect = Readonly<{
  x: number;
  y: number;
  width: number;
  height: number;
}>;

export type BoardLink = BoardRect & (
  | Readonly<{ kind: "youtube"; videoId: string }>
  | Readonly<{ kind: "externalUrl"; url: string }>
);

export type PdfDocument = Readonly<{
  path: string;
  pageCount: 1;
  geometry: PageGeometry;
  rawLinks: readonly RawLinkAnnotation[];
  buildId: string;
}>;

export type SiteManifest = Readonly<{
  version: 1;
  buildId: string;
  board: Readonly<{ width: number; height: number }>;
  links: readonly BoardLink[];
}>;

export function boxWidth(box: PdfBox): number {
  return box.x2 - box.x1;
}

export function boxHeight(box: PdfBox): number {
  return box.y2 - box.y1;
}

export function boardSize(geometry: PageGeometry): { width: number; height: number } {
  const width = boxWidth(geometry.cropBox);
  const height = boxHeight(geometry.cropBox);
  return geometry.rotation === 90 || geometry.rotation === 270
    ? { width: height, height: width }
    : { width, height };
}
