---
type: Architecture View
title: Software factory architecture
description: Module boundaries and data flow for mixed SVG and raster site generation.
timestamp: 2026-08-20
---
# Architecture

## Data Flow

The production path is:

```text
one repository PDF
  -> pdf-toolbox objects and streams
  -> deterministic image classification
       -> opaque or near-opaque content: raster resource
       -> substantially transparent artwork: traced vector resource
       -> ambiguous content: typed build failure
  -> immutable Haskell graphics-state interpreter
  -> Scene 'Unvalidated
  -> validateScene
  -> Scene 'Validated
  -> generated JavaScript scene plus referenced raster assets
  -> inline SVG, DOM overlays, and lazy YouTube iframe
  -> GitHub Pages
```

The independent development feedback path is:

```text
source PDF -> Poppler reference PNGs at 18 and 72 DPI
generated dist/ -> matching headless Chromium screenshots
each pair -> numerical comparison plus amplified difference image
```

The Poppler image is written only under `build/evaluation/`. It is never copied into `dist/`.

## Module Boundaries

| Module | Responsibility | Effects |
| --- | --- | --- |
| `Factory.Domain` | Coordinates, matrices, nodes, assets, URLs, validation phases, and errors | None |
| `Factory.Geometry` | PDF-to-board transformations and affine matrix operations | None |
| `Factory.Interpreter` | PDF operator state machine and scene-node emission | None |
| `Factory.Vectorize` | Classify image resources and trace eligible pixels into simplified, normalized SVG contours | None |
| `Factory.Pdf` | Open PDF, resolve objects, decode streams, prepare visual resources, materialize referenced raster assets, and extract annotations | File input and asset output |
| `Factory.Site` | Validate scene and emit deterministic site files | Site output |
| `Factory.Evaluation` | Run external oracle/browser and compare pixels | Processes and report output |
| `Factory.Pipeline` | Discover input, stage builds, promote valid output, dispatch commands | Filesystem orchestration |

`site/runtime.js` renders the already validated scene in original source order. Vector artwork and supported native paths use one board-sized SVG; raster resources use SVG `<image>` elements; links and controls use HTML. The runtime owns pan, zoom, touch, keyboard navigation, fullscreen, external links, and lazy YouTube activation. It does not understand PDF syntax or contain a Canvas fallback.

The approved rendering decision is recorded in [ADR 0001](/adr/0001-vector-first-mixed-rendering.md). Observable output behavior and its test design are recorded in [BDR 0001](/bdr/0001-mixed-scene-output.md).

## Safety Boundaries

The build applies these boundaries in order:

1. `discoverSinglePdf` requires exactly one non-symlink PDF below the repository root and skips generated directories.
2. The parser requires exactly one page and returns a `BuildError` for unsupported structures.
3. `classifyImage` preserves resources with no soft mask or at most `0.005` transparent samples, traces resources with at least `0.01` transparent samples, and rejects the interval between those thresholds.
4. `validateScene` checks finite positive dimensions, unique and referenced assets, asset references, colors, opacity, supported image transforms, and the full-board-raster prohibition.
5. `validateOutputPath` rejects output, staging, or backup directories that equal or contain the repository root; parent symlinks are resolved before this check.
6. The site is written to `DIST.building`; promotion keeps the previous output at `DIST.previous` until the replacement succeeds.
7. `make validate-dist` checks the exact 35-vector/9-raster source profile, referenced asset count, inline vector nodes, relative URLs, absence of Canvas fallback, and absence of deployed PDFs.

## Determinism

- PDF resources are sorted before preparation.
- Classification, color quantization, contour traversal, and simplification are pure and ordered.
- Only raster assets referenced by interpreted scene nodes are materialized.
- Generated JSON contains no timestamp or random identifier.
- The dependency solver is fixed by `cabal.project.freeze`.
- GHC and Cabal versions are fixed in both GitHub workflows.
- Evaluation fixes browser device scale and records per-resolution and aggregate results in `evaluation.json`.

The evaluation depends on the installed Poppler and Chrome renderers, so small antialiasing differences can still occur across package revisions. CI selects the `ubuntu-24.04` runner family and evaluates against explicit tolerances rather than exact pixel equality. The PR review diagram at `visual-explanations/haskell-software-factory.svg` shows this production and feedback flow and is deleted from `main` after merge.
