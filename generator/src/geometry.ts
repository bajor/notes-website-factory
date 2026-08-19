import { boxHeight, boxWidth, type PageGeometry, type Rect } from "./domain.js";

export function normalizeRect(rect: Rect): Rect | null {
  if (![rect.x, rect.y, rect.width, rect.height].every(Number.isFinite)) {
    return null;
  }
  const x = rect.width < 0 ? rect.x + rect.width : rect.x;
  const y = rect.height < 0 ? rect.y + rect.height : rect.y;
  return { x, y, width: Math.abs(rect.width), height: Math.abs(rect.height) };
}

export function pdfToBoardCoordinates(rect: Rect, page: PageGeometry): Rect | null {
  const normalized = normalizeRect(rect);
  if (!normalized) return null;

  const crop = page.cropBox;
  const x1 = normalized.x - crop.x1;
  const x2 = normalized.x + normalized.width - crop.x1;
  const y1 = normalized.y - crop.y1;
  const y2 = normalized.y + normalized.height - crop.y1;
  const points = rotatePoints(page, x1, y1, x2, y2);
  return normalizeRect({
    x: Math.min(points[0][0], points[1][0]),
    y: Math.min(points[0][1], points[1][1]),
    width: Math.abs(points[1][0] - points[0][0]),
    height: Math.abs(points[1][1] - points[0][1]),
  });
}

function rotatePoints(
  page: PageGeometry,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): readonly [readonly [number, number], readonly [number, number]] {
  const width = boxWidth(page.cropBox);
  const height = boxHeight(page.cropBox);
  switch (page.rotation) {
    case 0: return [[x1, height - y2], [x2, height - y1]];
    case 90: return [[y1, x1], [y2, x2]];
    case 180: return [[width - x2, y1], [width - x1, y2]];
    case 270: return [[height - y2, width - x2], [height - y1, width - x1]];
  }
}
