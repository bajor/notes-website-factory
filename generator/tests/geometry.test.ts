import { describe, expect, it } from "vitest";
import type { PageGeometry } from "../src/domain.js";
import { normalizeRect, pdfToBoardCoordinates } from "../src/geometry.js";

const page: PageGeometry = {
  mediaBox: { x1: 0, y1: 0, x2: 100, y2: 100 },
  cropBox: { x1: 0, y1: 0, x2: 100, y2: 100 },
  rotation: 0,
};

describe("PDF geometry", () => {
  it("maps the PDF bottom-left coordinate system to a top-left board", () => {
    expect(pdfToBoardCoordinates({ x: 0, y: 90, width: 10, height: 10 }, page))
      .toEqual({ x: 0, y: 0, width: 10, height: 10 });
  });

  it("normalizes a negative rectangle width", () => {
    expect(normalizeRect({ x: 10, y: 10, width: -5, height: 4 }))
      .toEqual({ x: 5, y: 10, width: 5, height: 4 });
  });

  it("normalizes a negative rectangle height", () => {
    expect(normalizeRect({ x: 10, y: 10, width: 5, height: -4 }))
      .toEqual({ x: 10, y: 6, width: 5, height: 4 });
  });
});
