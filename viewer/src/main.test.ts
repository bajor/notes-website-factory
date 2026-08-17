import { describe, expect, it } from 'vitest';
import { isClick } from './interaction';

describe('isClick', () => {
  it('accepts small pointer movement as a click', () => {
    expect(isClick({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(true);
  });

  it('rejects large pointer movement as a drag', () => {
    expect(isClick({ x: 0, y: 0 }, { x: 10, y: 0 })).toBe(false);
  });
});
