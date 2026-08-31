import { scene as manyTopicsScene } from './scene.many-topics.generated.js';

export const scene = {
  ...manyTopicsScene,
  topics: manyTopicsScene.topics.slice(0, 10),
};
