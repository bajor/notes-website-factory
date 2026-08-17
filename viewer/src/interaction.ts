export function isClick(start: { x: number; y: number }, end: { x: number; y: number }): boolean {
  return Math.hypot(start.x - end.x, start.y - end.y) < 6;
}
