import { describe, expect, it } from 'vitest';
import { containsPoint, scaleRect } from './geometry';

describe('scaleRect', () => {
  it('converts PDF point coordinates to rendered image pixels', () => {
    expect(scaleRect(
      { x: 72, y: 70, width: 180, height: 60 },
      { width: 420, height: 320 },
      { width: 1050, height: 800 },
    )).toEqual({ x: 180, y: 175, width: 450, height: 150 });
  });
});

describe('containsPoint', () => {
  it('identifies a point inside a board region', () => {
    expect(containsPoint(
      { x: 100, y: 200, width: 50, height: 80 },
      { x: 125, y: 240 },
    )).toBe(true);
  });
});
