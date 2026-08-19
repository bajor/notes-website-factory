# Architecture

The repository contains exactly one maintained PDF, and that PDF contains exactly one page. The page is one spatial Freeform board rather than a document with page navigation.

## Build Pipeline

```text
single discovered PDF
  -> Poppler page validation and geometry
  -> QPDF URI annotations
  -> pure TypeScript geometry and URL transformations
  -> Poppler high-resolution PNG render
  -> Sharp/libvips Deep Zoom pyramid
  -> manifest and static TypeScript viewer
  -> GitHub Pages
```

The browser never parses the PDF. Build-time native tools handle PDF compatibility and rendering, while the deployed output consists only of static HTML, CSS, JavaScript, JSON, XML, and PNG tiles.

## Generator Boundaries

The generator uses a functional-core and imperative-shell design:

- `generator/src/discovery.ts` recursively discovers the single source PDF.
- `generator/src/pdf.ts` owns Poppler and QPDF process calls and converts their output into typed values.
- `generator/src/geometry.ts`, `links.ts`, and `manifest.ts` perform deterministic transformations without filesystem or process access.
- `generator/src/render.ts` owns PDF rasterization and Deep Zoom generation.
- `generator/src/pipeline.ts` owns filesystem effects and composes the complete build.
- `generator/src/cli.ts` provides the human-readable `inspect` and `build` commands.

The TypeScript types use discriminated unions for YouTube and external links, so a YouTube link cannot exist without a video ID and an external link cannot exist without its URL.

## Coordinates

PDF annotation rectangles use a bottom-left origin. The viewer and rendered image use a top-left origin. `geometry.ts` applies CropBox offsets, axis inversion, and page rotation before an annotation enters `manifest.json`. Manifest validation rejects non-positive or out-of-bounds link rectangles.

## Rendering

Poppler renders the PDF at 180 dots per inch to preserve the source appearance. Sharp/libvips converts that render into a standard Deep Zoom Image pyramid with 256-pixel lossless PNG tiles, including every level from a one-pixel overview through the full-resolution image.

OpenSeadragon loads only the tiles needed for the current viewport and provides mouse, trackpad, keyboard, touch, and pinch interactions. Controls are deliberately limited to zoom, fit, and fullscreen.

## Link Policy

Only `/Link` annotations with `/URI` actions are interactive. HTTP and HTTPS URLs are accepted. Supported YouTube URL forms are classified into embedded videos; every other accepted web URL opens externally.

The rendered appearance alone never creates an interactive element. There is no optical character recognition, computer vision, external metadata lookup, or build-time artificial intelligence.

## Reproducibility

- PDF discovery and annotation ordering are deterministic.
- The manifest build ID is the SHA-256 digest of the source PDF.
- JSON output is formatted deterministically and contains no timestamp.
- Deep Zoom paths and level numbering follow the standard layout.
- CI and deployment install dependencies from committed npm lockfiles.
- CI and deployment pin the Ubuntu runner, Node.js, Poppler package, and QPDF package versions.
