import { scene } from './scene.generated.js';

const viewport = document.querySelector('#viewport');
const board = document.querySelector('#board');
const status = document.querySelector('#status');
const evaluationMode = new URLSearchParams(window.location.search).has('evaluation');

const view = { scale: 1, x: 0, y: 0 };
const pointers = new Map();
let dragStart = null;
let pinchStart = null;

void initialize();

async function initialize() {
  try {
    if (evaluationMode) {
      document.querySelector('#controls').hidden = true;
      // The evaluator renders its PDF oracle at 18 DPI. PDF coordinates use
      // 72 points per inch, so 18 / 72 gives the matching browser scale.
      view.scale = 0.25;
      applyView();
    } else {
      installControls();
      fitBoard();
    }
    await buildScene();
    await document.fonts.ready;
    status.remove();
    document.body.dataset.ready = 'true';
  } catch (error) {
    status.textContent = `Scene failed: ${error.message}`;
    document.body.dataset.failed = 'true';
    throw error;
  }
}

async function buildScene() {
  board.style.width = `${scene.width}px`;
  board.style.height = `${scene.height}px`;

  const assets = new Map(scene.assets.map((asset) => [asset.id, asset]));
  const imageLoads = [];

  for (const node of scene.nodes) {
    if (node.kind === 'image') imageLoads.push(addImage(node, assets));
    if (node.kind === 'path') addPath(node);
    if (node.kind === 'text') addText(node);
    if (node.kind === 'link') addLink(node);
  }

  await Promise.all(imageLoads);
}

function addImage(node, assets) {
  const asset = assets.get(node.asset);
  if (!asset) throw new Error(`Missing generated asset ${node.asset}`);

  const image = document.createElement('img');
  image.className = 'scene-image';
  image.src = asset.file;
  image.alt = '';
  image.draggable = false;
  image.style.opacity = node.opacity;
  const bounds = transformedUnitBounds(node.matrix);
  image.style.left = `${bounds.x}px`;
  image.style.top = `${bounds.y}px`;
  image.style.width = `${bounds.width}px`;
  image.style.height = `${bounds.height}px`;
  image.style.transformOrigin = 'center';
  image.style.transform = `scale(${Math.sign(node.matrix.a)}, ${-Math.sign(node.matrix.d)})`;
  appendWithClips(image, node.clips);

  return new Promise((resolve, reject) => {
    image.addEventListener('load', resolve, { once: true });
    image.addEventListener('error', () => reject(new Error(`Could not load ${asset.file}`)), { once: true });
  });
}

function addPath(node) {
  const bounds = pathBounds(node.commands, node.style.lineWidth);
  if (!bounds) return;

  const canvas = document.createElement('canvas');
  canvas.className = 'scene-path';
  canvas.width = Math.max(1, Math.ceil(bounds.width));
  canvas.height = Math.max(1, Math.ceil(bounds.height));
  canvas.style.left = `${bounds.x}px`;
  canvas.style.top = `${bounds.y}px`;
  canvas.style.width = `${bounds.width}px`;
  canvas.style.height = `${bounds.height}px`;

  const context = canvas.getContext('2d');
  context.translate(-bounds.x, -bounds.y);
  context.globalAlpha = node.style.opacity;
  tracePath(context, node.commands);
  if (node.style.fill) {
    context.fillStyle = cssColor(node.style.fill.color);
    context.fill(node.style.fill.rule);
  }
  if (node.style.stroke) {
    context.strokeStyle = cssColor(node.style.stroke);
    context.lineWidth = node.style.lineWidth;
    context.stroke();
  }
  appendWithClips(canvas, node.clips);
}

function addText(node) {
  const text = document.createElement('span');
  text.className = 'scene-text';
  text.textContent = node.value;
  text.style.fontFamily = node.fontFamily;
  text.style.fontSize = `${node.fontSize}px`;
  text.style.opacity = node.opacity;
  text.style.transform = cssMatrix(node.matrix);
  appendWithClips(text, node.clips);
}

function addLink(node) {
  const element = document.createElement(node.target.kind === 'external' ? 'a' : 'button');
  element.className = 'scene-link';
  positionLink(element, node.bounds);
  if (node.target.kind === 'external') {
    element.href = node.target.url;
    element.target = '_blank';
    element.rel = 'noopener noreferrer';
    element.setAttribute('aria-label', `Open ${node.target.url}`);
  } else {
    element.type = 'button';
    element.setAttribute('aria-label', 'Play YouTube video');
    element.addEventListener('click', () => activateYouTube(element, node.target));
  }
  board.append(element);
}

function activateYouTube(element, target) {
  const iframe = document.createElement('iframe');
  iframe.className = 'scene-link scene-embed';
  iframe.style.cssText = element.style.cssText;
  iframe.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(target.videoId)}`;
  iframe.title = 'YouTube video player';
  iframe.allow = 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
  iframe.allowFullscreen = true;
  element.replaceWith(iframe);
}

function positionLink(element, bounds) {
  element.style.left = `${bounds.x}px`;
  element.style.top = `${bounds.y}px`;
  element.style.width = `${bounds.width}px`;
  element.style.height = `${bounds.height}px`;
}

function appendWithClips(element, clips) {
  let child = element;
  for (const clip of [...clips].reverse()) {
    const wrapper = document.createElement('div');
    wrapper.className = 'scene-layer';
    wrapper.style.inset = '0';
    wrapper.style.clipPath = `path('${pathData(clip.commands)}')`;
    wrapper.append(child);
    child = wrapper;
  }
  board.append(child);
}

function installControls() {
  document.querySelector('[data-action="zoom-in"]').addEventListener('click', () => zoomAt(1.35, viewport.clientWidth / 2, viewport.clientHeight / 2));
  document.querySelector('[data-action="zoom-out"]').addEventListener('click', () => zoomAt(1 / 1.35, viewport.clientWidth / 2, viewport.clientHeight / 2));
  document.querySelector('[data-action="fit"]').addEventListener('click', fitBoard);
  document.querySelector('[data-action="fullscreen"]').addEventListener('click', () => void document.documentElement.requestFullscreen?.());
  viewport.addEventListener('wheel', onWheel, { passive: false });
  viewport.addEventListener('pointerdown', onPointerDown);
  viewport.addEventListener('pointermove', onPointerMove);
  viewport.addEventListener('pointerup', onPointerEnd);
  viewport.addEventListener('pointercancel', onPointerEnd);
  viewport.addEventListener('keydown', onKeyDown);
  window.addEventListener('resize', fitBoard);
}

function onKeyDown(event) {
  if (event.target !== viewport) return;
  const panStep = 48;
  const movement = {
    ArrowUp: [0, panStep],
    ArrowDown: [0, -panStep],
    ArrowLeft: [panStep, 0],
    ArrowRight: [-panStep, 0],
  }[event.key];
  if (!movement) return;
  event.preventDefault();
  view.x += movement[0];
  view.y += movement[1];
  applyView();
}

function onWheel(event) {
  event.preventDefault();
  zoomAt(Math.exp(-event.deltaY * 0.0015), event.clientX, event.clientY);
}

function onPointerDown(event) {
  if (event.target.closest('.scene-link')) return;
  viewport.setPointerCapture(event.pointerId);
  pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
  if (pointers.size === 1) dragStart = { pointer: pointers.get(event.pointerId), x: view.x, y: view.y };
  if (pointers.size === 2) pinchStart = currentPinch();
  viewport.classList.add('is-dragging');
}

function onPointerMove(event) {
  if (!pointers.has(event.pointerId)) return;
  pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
  if (pointers.size === 1 && dragStart) {
    const pointer = pointers.get(event.pointerId);
    view.x = dragStart.x + pointer.x - dragStart.pointer.x;
    view.y = dragStart.y + pointer.y - dragStart.pointer.y;
    applyView();
  }
  if (pointers.size === 2 && pinchStart) {
    const pinch = currentPinch();
    zoomAt(pinch.distance / pinchStart.distance, pinch.center.x, pinch.center.y);
    pinchStart = pinch;
  }
}

function onPointerEnd(event) {
  pointers.delete(event.pointerId);
  if (pointers.size < 2) pinchStart = null;
  if (pointers.size === 1) {
    const pointer = [...pointers.values()][0];
    dragStart = { pointer: { ...pointer }, x: view.x, y: view.y };
  }
  if (pointers.size === 0) {
    dragStart = null;
    viewport.classList.remove('is-dragging');
  }
}

function currentPinch() {
  const [first, second] = [...pointers.values()];
  return {
    center: { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 },
    distance: Math.hypot(second.x - first.x, second.y - first.y),
  };
}

function zoomAt(factor, screenX, screenY) {
  const nextScale = Math.min(16, Math.max(0.03, view.scale * factor));
  const boardX = (screenX - view.x) / view.scale;
  const boardY = (screenY - view.y) / view.scale;
  view.x = screenX - boardX * nextScale;
  view.y = screenY - boardY * nextScale;
  view.scale = nextScale;
  applyView();
}

function fitBoard() {
  const margin = 24;
  view.scale = Math.max(0.03, Math.min((viewport.clientWidth - margin * 2) / scene.width, (viewport.clientHeight - margin * 2) / scene.height));
  view.x = (viewport.clientWidth - scene.width * view.scale) / 2;
  view.y = (viewport.clientHeight - scene.height * view.scale) / 2;
  applyView();
}

function applyView() {
  board.style.transform = `translate(${view.x}px, ${view.y}px) scale(${view.scale})`;
}

function cssMatrix(matrix) {
  return `matrix(${matrix.a}, ${matrix.b}, ${matrix.c}, ${matrix.d}, ${matrix.e}, ${matrix.f})`;
}

// PDF image samples and DOM images use opposite vertical conventions. The
// caller keeps the matrix signs as CSS flips while this function owns layout.
function transformedUnitBounds(matrix) {
  const corners = [
    transformPoint(matrix, 0, 0),
    transformPoint(matrix, 1, 0),
    transformPoint(matrix, 0, 1),
    transformPoint(matrix, 1, 1),
  ];
  const xs = corners.map((point) => point.x);
  const ys = corners.map((point) => point.y);
  return {
    x: Math.min(...xs),
    y: Math.min(...ys),
    width: Math.max(...xs) - Math.min(...xs),
    height: Math.max(...ys) - Math.min(...ys),
  };
}

function transformPoint(matrix, x, y) {
  return {
    x: matrix.a * x + matrix.c * y + matrix.e,
    y: matrix.b * x + matrix.d * y + matrix.f,
  };
}

function cssColor(color) {
  return `rgb(${color.r * 255} ${color.g * 255} ${color.b * 255})`;
}

function tracePath(context, commands) {
  context.beginPath();
  for (const command of commands) {
    if (command.kind === 'move') context.moveTo(command.point.x, command.point.y);
    if (command.kind === 'line') context.lineTo(command.point.x, command.point.y);
    if (command.kind === 'curve') context.bezierCurveTo(command.first.x, command.first.y, command.second.x, command.second.y, command.end.x, command.end.y);
    if (command.kind === 'close') context.closePath();
  }
}

function pathData(commands) {
  return commands.map((command) => {
    if (command.kind === 'move') return `M ${command.point.x} ${command.point.y}`;
    if (command.kind === 'line') return `L ${command.point.x} ${command.point.y}`;
    if (command.kind === 'curve') return `C ${command.first.x} ${command.first.y} ${command.second.x} ${command.second.y} ${command.end.x} ${command.end.y}`;
    return 'Z';
  }).join(' ');
}

function pathBounds(commands, padding) {
  const points = commands.flatMap((command) => [command.point, command.first, command.second, command.end].filter(Boolean));
  if (points.length === 0) return null;
  const xs = points.map((point) => point.x);
  const ys = points.map((point) => point.y);
  const left = Math.min(...xs) - padding;
  const top = Math.min(...ys) - padding;
  return { x: left, y: top, width: Math.max(...xs) - left + padding, height: Math.max(...ys) - top + padding };
}
