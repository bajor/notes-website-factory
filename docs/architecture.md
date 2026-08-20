# Architecture

## Data Flow

The production path is:

```text
one repository PDF
  -> pdf-toolbox objects and streams
  -> immutable Haskell graphics-state interpreter
  -> Scene 'Unvalidated
  -> validateScene
  -> Scene 'Validated
  -> generated JavaScript scene plus extracted image assets
  -> DOM, Canvas, and lazy YouTube iframe
  -> GitHub Pages
```

The independent development feedback path is:

```text
source PDF -> Poppler reference PNG
generated dist/ -> headless Chromium screenshot
both images -> numerical comparison plus amplified difference image
```

The Poppler image is written only under `build/evaluation/`. It is never copied into `dist/`.

## Module Boundaries

| Module | Responsibility | Effects |
| --- | --- | --- |
| `Factory.Domain` | Coordinates, matrices, nodes, assets, URLs, validation phases, and errors | None |
| `Factory.Geometry` | PDF-to-board transformations and affine matrix operations | None |
| `Factory.Interpreter` | PDF operator state machine and scene-node emission | None |
| `Factory.Pdf` | Open PDF, resolve objects, decode streams, extract assets and annotations | File input and asset output |
| `Factory.Site` | Validate scene and emit deterministic site files | Site output |
| `Factory.Evaluation` | Run external oracle/browser and compare pixels | Processes and report output |
| `Factory.Pipeline` | Discover input, stage builds, promote valid output, dispatch commands | Filesystem orchestration |

`site/runtime.js` is deliberately small. It renders the already validated scene and owns pan, zoom, touch, keyboard navigation, fullscreen, external links, and lazy YouTube activation. It does not understand PDF syntax.

## Safety Boundaries

The build applies these boundaries in order:

1. `discoverSinglePdf` requires exactly one non-symlink PDF below the repository root and skips generated directories.
2. The parser requires exactly one page and returns a `BuildError` for unsupported structures.
3. `validateScene` checks finite positive dimensions, unique and valid assets, asset references, colors, opacity, supported image transforms, and the full-board-raster prohibition.
4. `validateOutputPath` rejects output, staging, or backup directories that equal or contain the repository root; parent symlinks are resolved before this check.
5. The site is written to `DIST.building`; promotion keeps the previous output at `DIST.previous` until the replacement succeeds.
6. `make validate-dist` checks required files, extracted assets, relative URLs, and absence of deployed PDFs.

## Determinism

- PDF resources are sorted before asset extraction.
- Generated JSON contains no timestamp or random identifier.
- The dependency solver is fixed by `cabal.project.freeze`.
- GHC and Cabal versions are fixed in both GitHub workflows.
- Evaluation fixes browser device scale and records all numerical thresholds in `evaluation.json`.

The evaluation depends on the installed Poppler and Chrome renderers, so small antialiasing differences can still occur across package revisions. CI selects the `ubuntu-24.04` runner family and evaluates against explicit tolerances rather than exact pixel equality.
