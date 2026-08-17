import OpenSeadragon from 'openseadragon';
import { isClick } from './interaction';
import './style.css';

type Manifest = {
  version: number;
  buildId: string;
  board: { width: number; height: number };
  links: Array<{
    x: number;
    y: number;
    width: number;
    height: number;
    kind: 'youtube' | 'externalUrl';
    videoId?: string;
    video_id?: string;
    url?: string;
  }>;
};

async function main(): Promise<void> {
  const manifest = await fetch('manifest.json').then((response) => response.json()) as Manifest;
  const viewer = OpenSeadragon({
    id: 'viewer',
    tileSources: 'board.dzi',
    showNavigationControl: false,
    gestureSettingsTouch: { pinchToZoom: true, dragToPan: true, clickToZoom: false, dblClickToZoom: true },
    gestureSettingsMouse: { clickToZoom: false, dblClickToZoom: true },
  });

  viewer.addHandler('open', () => {
    viewer.viewport.goHome(true);
    addOverlays(viewer, manifest);
  });

  document.getElementById('zoom-in')?.addEventListener('click', () => viewer.viewport.zoomBy(1.4));
  document.getElementById('zoom-out')?.addEventListener('click', () => viewer.viewport.zoomBy(0.7));
  document.getElementById('fit')?.addEventListener('click', () => viewer.viewport.goHome());
  document.getElementById('reset')?.addEventListener('click', () => viewer.viewport.goHome());
  document.getElementById('fullscreen')?.addEventListener('click', () => document.documentElement.requestFullscreen?.());
  document.addEventListener('keydown', (event) => {
    if (event.key === '+') viewer.viewport.zoomBy(1.4);
    if (event.key === '-') viewer.viewport.zoomBy(0.7);
    if (event.key === '0') viewer.viewport.goHome();
    if (event.key === 'f') document.documentElement.requestFullscreen?.();
  });
}

function addOverlays(viewer: OpenSeadragon.Viewer, manifest: Manifest): void {
  for (const link of manifest.links) {
    const element = document.createElement('button');
    element.className = 'link-overlay';
    element.type = 'button';
    element.setAttribute('aria-label', link.kind.toLowerCase().includes('youtube') ? 'Play YouTube video' : 'Open link');
    let pointerStart: { x: number; y: number } | null = null;
    element.addEventListener('pointerdown', (event) => { pointerStart = { x: event.clientX, y: event.clientY }; });
    element.addEventListener('pointerup', (event) => {
      if (!pointerStart || !isClick(pointerStart, { x: event.clientX, y: event.clientY })) return;
      const videoId = link.videoId ?? link.video_id;
      if (videoId) {
        activateYoutube(element, videoId);
      } else if (link.url) {
        window.open(link.url, '_blank', 'noopener,noreferrer');
      }
    });
    viewer.addOverlay({
      element,
      location: viewer.viewport.imageToViewportRectangle(link.x, link.y, link.width, link.height),
    });
  }
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
}

main().catch((error) => {
  document.body.textContent = `Failed to load notes viewer: ${error}`;
});
