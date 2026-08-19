import OpenSeadragon from 'openseadragon';
import { containsPoint, scaleRect, type Rect } from './geometry';
import './style.css';

type BoardRect = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type InteractiveOverlay = Readonly<{
  element: HTMLElement;
  imageRect: Rect;
  link: BoardLink;
}>;

type BoardLink = BoardRect & (
  | { kind: 'youtube'; videoId: string }
  | { kind: 'externalUrl'; url: string }
);

type Manifest = {
  version: number;
  buildId: string;
  board: { width: number; height: number };
  links: BoardLink[];
};

async function main(): Promise<void> {
  const manifest = await loadManifest();
  const viewer = OpenSeadragon({
    id: 'viewer',
    tileSources: 'board.dzi',
    showNavigationControl: false,
    animationTime: 0.65,
    blendTime: 0.1,
    constrainDuringPan: true,
    visibilityRatio: 0.35,
    maxZoomPixelRatio: 2,
    gestureSettingsTouch: { pinchToZoom: true, dragToPan: true, clickToZoom: false, dblClickToZoom: true },
    gestureSettingsMouse: { clickToZoom: false, dblClickToZoom: true },
  });

  viewer.addHandler('open', () => {
    document.getElementById('status')?.remove();
    viewer.viewport.goHome(false);
    const overlays = addOverlays(viewer, manifest);
    addCanvasActivation(viewer, overlays);
  });

  document.getElementById('zoom-in')?.addEventListener('click', () => zoom(viewer, 1.4));
  document.getElementById('zoom-out')?.addEventListener('click', () => zoom(viewer, 1 / 1.4));
  document.getElementById('fit')?.addEventListener('click', () => viewer.viewport.goHome());
  document.getElementById('fullscreen')?.addEventListener('click', enterFullscreen);
  document.addEventListener('keydown', (event) => {
    if (event.key === '+') zoom(viewer, 1.4);
    if (event.key === '-') zoom(viewer, 1 / 1.4);
    if (event.key === '0') viewer.viewport.goHome();
    if (event.key.toLowerCase() === 'f') enterFullscreen();
  });
}

function addOverlays(viewer: OpenSeadragon.Viewer, manifest: Manifest): InteractiveOverlay[] {
  const image = viewer.world.getItemAt(0);
  const contentSize = image.getContentSize();
  const renderedBoard = { width: contentSize.x, height: contentSize.y };
  return manifest.links.map((link) => {
    const element = document.createElement('div');
    element.className = 'link-overlay';
    element.role = 'button';
    element.tabIndex = 0;
    element.setAttribute('aria-label', link.kind === 'youtube' ? 'Play YouTube video' : 'Open link');
    element.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      event.preventDefault();
      activateLink(element, link);
    });
    const imageRect = scaleRect(link, manifest.board, renderedBoard);
    viewer.addOverlay({
      element,
      location: image.imageToViewportRectangle(
        imageRect.x,
        imageRect.y,
        imageRect.width,
        imageRect.height,
      ),
    });
    return { element, imageRect, link };
  });
}

function addCanvasActivation(viewer: OpenSeadragon.Viewer, overlays: readonly InteractiveOverlay[]): void {
  const image = viewer.world.getItemAt(0);
  viewer.addHandler('canvas-click', (event) => {
    if (!event.quick) return;
    const viewportPoint = viewer.viewport.pointFromPixel(event.position);
    const imagePoint = image.viewportToImageCoordinates(viewportPoint);
    const overlay = overlays.find((candidate) => containsPoint(candidate.imageRect, imagePoint));
    if (!overlay) return;
    event.preventDefaultAction = true;
    activateLink(overlay.element, overlay.link);
  });
}

function activateLink(element: HTMLElement, link: BoardLink): void {
  if (link.kind === 'youtube') activateYoutube(element, link.videoId);
  else window.open(link.url, '_blank', 'noopener,noreferrer');
}

function activateYoutube(container: HTMLElement, videoId: string): void {
  if (container.querySelector('iframe')) return;
  const iframe = document.createElement('iframe');
  iframe.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(videoId)}`;
  iframe.title = 'YouTube video player';
  iframe.allow = 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
  iframe.allowFullscreen = true;
  container.replaceChildren(iframe);
  container.classList.add('is-active');
  container.removeAttribute('role');
  container.removeAttribute('aria-label');
  container.tabIndex = -1;
}

async function loadManifest(): Promise<Manifest> {
  const response = await fetch('manifest.json');
  if (!response.ok) throw new Error(`manifest request returned ${response.status}`);
  return response.json() as Promise<Manifest>;
}

function zoom(viewer: OpenSeadragon.Viewer, factor: number): void {
  viewer.viewport.zoomBy(factor);
  viewer.viewport.applyConstraints();
}

function enterFullscreen(): void {
  void document.documentElement.requestFullscreen?.().catch(() => undefined);
}

main().catch((error) => {
  const status = document.getElementById('status');
  if (status) status.textContent = `Failed to load notes: ${error instanceof Error ? error.message : String(error)}`;
});
