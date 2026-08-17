# Architecture

`notes.pdf` is the single source of truth. The repository accepts exactly one PDF page and rejects every other page count.

Pipeline:

```text
notes.pdf
  -> Poppler adapter
  -> immutable Rust document model
  -> pure geometry and URL transformations
  -> manifest.json
  -> PNG Deep Zoom tile pyramid
  -> TypeScript OpenSeadragon viewer
  -> GitHub Pages
```

The generator uses Rust because the core model benefits from explicit `Result` errors, enums, immutable values, deterministic serialization, and property-based tests.

Custom PDF parsing is forbidden. Page boxes and rendering are delegated to Poppler, and annotation extraction is delegated to QPDF JSON output, because PDF parsing is a large compatibility problem and not part of this project.

Effects live in `generator/src/pdf_adapter.rs` and `generator/src/main.rs`. Pure transformations live in `domain.rs`, `geometry.rs`, `links.rs`, `manifest.rs`, and `render.rs`.

The canonical board coordinate system uses top-left origin and PDF point units. `geometry.rs` owns conversion from PDF rectangles to board rectangles, including crop offsets, axis inversion, and page rotation.

Rendering uses a tile pyramid instead of one huge browser image. `pdftoppm` renders the single page to a high-resolution PNG, and `render.rs` generates standard Deep Zoom Image tiles under `dist/board_files/` plus `dist/board.dzi`.

The viewer uses OpenSeadragon because it already solves tiled loading, pan, zoom, mouse, trackpad, touch, pinch zoom, and image-space overlays.

YouTube links come from PDF URI annotations only. The generator does not use OCR, computer vision, external APIs, or build-time AI. A YouTube-looking image without a URI annotation remains visible but cannot become an embedded video.

YouTube iframes are lazy. The initial page renders only the board tiles and transparent overlays. When a user activates a YouTube region, the viewer inserts a `youtube-nocookie.com` iframe inside that exact overlay rectangle.

Determinism rules:

- manifest links are sorted deterministically;
- JSON is pretty-printed from typed structures;
- tile paths are deterministic;
- build identity is the SHA-256 of `notes.pdf`;
- no generated timestamps are written into artifacts.

GitHub Pages deployment is owned by `.github/workflows/pages.yml` and deploys `dist/` with the official Pages actions. The repository is designed as an independent project site at `https://<user>.github.io/<repository>/`, so it does not interfere with a separate user-site or blog repository at `https://<user>.github.io/`.
