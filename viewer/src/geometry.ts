export type Rect = Readonly<{ x: number; y: number; width: number; height: number }>;
export type Size = Readonly<{ width: number; height: number }>;
export type Point = Readonly<{ x: number; y: number }>;

export function scaleRect(rect: Rect, source: Size, destination: Size): Rect {
  const scaleX = destination.width / source.width;
  const scaleY = destination.height / source.height;
  return {
    x: rect.x * scaleX,
    y: rect.y * scaleY,
    width: rect.width * scaleX,
    height: rect.height * scaleY,
  };
}

export function containsPoint(rect: Rect, point: Point): boolean {
  return point.x >= rect.x
    && point.y >= rect.y
    && point.x <= rect.x + rect.width
    && point.y <= rect.y + rect.height;
}
