export const scene = {
  width: 200,
  height: 140,
  assets: [],
  nodes: [
    {
      kind: 'link',
      target: { kind: 'game', url: 'https://bajor.github.io/algo-arcade/#/games/example-game' },
      bounds: { x: 20, y: 20, width: 60, height: 60 },
    },
    {
      kind: 'link',
      target: { kind: 'youtube', videoId: 'abcdefghijk' },
      bounds: { x: 100, y: 20, width: 60, height: 60 },
    },
    {
      kind: 'link',
      target: { kind: 'game', url: 'https://bajor.github.io/algo-arcade/#/games/%FF' },
      bounds: { x: 20, y: 100, width: 60, height: 20 },
    },
  ],
};
