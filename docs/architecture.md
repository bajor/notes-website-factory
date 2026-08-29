---
type: Architecture View
title: Notes website factory architecture
description: Repository ownership, reusable workflow, module boundaries, and evaluation flow.
timestamp: 2026-08-28
---
# Architecture

## System Context

```mermaid
flowchart LR
  subgraph Consumer[Consumer repository]
    PDF[One-page Freeform PDF]
    Caller[Caller workflow and site title]
    Deploy[Pages deployment job]
  end

  subgraph Factory[Notes Website Factory]
    Workflow[Reusable build workflow]
    Generator[Haskell generator]
    Viewer[Shared viewer templates]
    Oracle[Visual evaluator]
  end

  PagesArtifact[github-pages artifact]
  EvidenceArtifact[pdf-site-evaluation artifact]
  Pages[Consumer GitHub Pages]

  Caller --> Workflow
  PDF --> Workflow
  Workflow --> Generator
  Viewer --> Generator
  Generator --> Oracle
  Oracle --> PagesArtifact
  Oracle --> EvidenceArtifact
  PagesArtifact --> Deploy --> Pages
```

The consumer controls content identity and deployment authority. The factory controls every transformation from PDF objects to a validated browser product. The reusable workflow has only `contents: read`; it cannot deploy or request an OpenID Connect token.

## Checkout and Build Sequence

```mermaid
sequenceDiagram
  participant C as Consumer caller
  participant W as Reusable workflow
  participant S as source/
  participant F as factory/
  participant G as Haskell generator
  participant E as Evaluator
  participant A as Artifact store

  C->>W: site-title
  W->>S: Checkout caller commit
  W->>F: Checkout job.workflow_repository at job.workflow_sha
  W->>G: Test factory fixture
  W->>G: Inspect source only
  G->>S: Discover exactly one PDF
  G->>F: Read shared templates
  G-->>W: Validated static site
  W->>E: Compare Poppler and Chromium at 18 and 72 DPI
  E-->>A: pdf-site-evaluation
  alt every scale passes
    W-->>A: github-pages
  else parsing, validation, or evaluation fails
    W-->>C: Failed workflow without Pages artifact
  end
```

Separate checkout and output roots prevent a factory fixture from contaminating consumer discovery. `job.workflow_sha` prevents a workflow loaded from one commit from independently checking out different generator code, including when callers use `@main`.

## Production Data Flow

```mermaid
flowchart TD
  Input[Exactly one one-page PDF]
  Parse[pdf-toolbox objects and streams]
  Mask{Soft mask state}
  SourceAlpha{Nonzero source alpha}
  Traceable{Traceable alpha sample}
  Fraction{Non-opaque fraction}
  Raster[Preserve raster resource]
  Vector[Trace normalized SVG contours]
  Reject[Typed unsupported-image failure]
  Links[Extract URI annotations]
  Target{Classify link target}
  YouTube[YouTube activation button]
  Game[Algo Arcade anchor and badge]
  External[External anchor]
  Interpret[Immutable graphics-state interpreter<br/>including named colors, miters, and dashes]
  Raw[Scene Unvalidated]
  Validate[validateScene]
  Valid[Scene Validated]
  Emit[Static JavaScript scene and assets]
  Affine[Affine image presentation matrix]
  Browser[Inline SVG, DOM overlays, shared controls]

  Input --> Parse --> Mask
  Parse --> Links --> Target
  Mask -->|absent| Raster
  Mask -->|empty| Reject
  Mask --> SourceAlpha
  SourceAlpha -->|all zero| Reject
  SourceAlpha -->|nonzero| Traceable
  Traceable -->|none| Raster
  Traceable -->|present| Fraction
  Fraction -->|at most 0.01| Raster
  Fraction -->|between 0.01 and 0.02| Reject
  Fraction -->|at least 0.02| Vector
  Target -->|supported video| YouTube
  Target -->|exact game route| Game
  Target -->|other HTTP or HTTPS| External
  Raster --> Interpret
  Vector --> Interpret
  Interpret --> Raw
  YouTube --> Raw
  Game --> Raw
  External --> Raw
  Raw --> Validate --> Valid --> Emit --> Affine --> Browser
```

The production path never renders a full-page PDF image. Low-alpha content that the vector tracer cannot represent uses the existing lossless RGBA raster path. The shared viewer composes each PDF image matrix with the image-sample vertical orientation, preserving rotation and shear for raster and traced artwork. Poppler exists only in the independent evaluation path. Data-flow drift is caught by focused tests, real-consumer evaluation, and review of this diagram.

## Module Boundaries

| Module | Responsibility | Effects |
| --- | --- | --- |
| `Factory.Domain` | Coordinates, matrices, color spaces, paint styles, nodes, typed link targets, assets, titles, validation phases, and errors | None |
| `Factory.Geometry` | PDF-to-board transformations and affine matrix operations | None |
| `Factory.Interpreter` | PDF operator state machine and scene-node emission | None |
| `Factory.Vectorize` | Image classification, quantization, contour tracing, and simplification | None |
| `Factory.Pdf` | PDF objects, streams, resources, annotations, structural URL classification, and raster materialization | File input and asset output |
| `Factory.Site` | Scene validation, metadata rendering, and deterministic site emission | Template and site output |
| `Factory.Evaluation` | Poppler/Chromium execution, metrics, images, and reports | Processes and report output |
| `Factory.Pipeline` | CLI dispatch, discovery, protected paths, staging, and promotion | Filesystem orchestration |
| `site/runtime.js` | Shared affine rendering, typed link activation, game affordances, and desktop/mobile interaction behavior | Browser DOM |
| `build-pdf-site.yml` | Isolated checkouts, toolchain, evaluation, and artifact upload | GitHub Actions |

## Safety Boundaries

1. `discoverSinglePdf` scans only the consumer source root and requires one non-symlink PDF.
2. The parser requires exactly one page and fails on unsupported structures.
3. `classifyImage` rejects empty and all-zero masks, preserves nonzero masks with no traceable sample, then applies the `0.01` raster boundary, the ambiguity interval, and the `0.02` vector boundary to traceable masks.
4. `validateScene` checks dimensions, references, finite values, paint values including miter limits and dash patterns, opacities, and the full-board-raster prohibition by testing every board corner against the transformed image bounds.
5. Existing removable locations are canonicalized, while symlink targets and unresolved symlink parents are rejected; removable paths cannot overlap source, templates, or another independently owned output root.
6. Output is written to `DIST.building` before atomic-style promotion through `DIST.previous`.
7. Distribution checks require product files, relative references, no PDF, and no Canvas fallback without assuming scene counts.
8. The Pages artifact is uploaded only after parsing, validation, browser readiness, and both visual scales pass.
9. A game target requires HTTPS, the exact case-insensitive host `bajor.github.io`, no credentials or explicit port, path `/algo-arcade/`, and a non-empty `#/games/` fragment route. Matching never uses substring checks.
10. The game badge appears only in normal interactive mode; evaluation mode retains the native link hit area but draws only PDF-derived pixels.

## Determinism and Compatibility

- PDF resources, classification, contours, and generated JSON remain deterministically ordered.
- The dependency solver, GHC, Cabal, and third-party actions are pinned.
- Poppler and Chrome revisions can change antialiasing, so fixed tolerances replace exact pixel equality.
- `site-title`, `github-pages`, `pdf-site-evaluation`, and generated filenames are public contracts.
- A moving `main` reference intentionally updates consumers on their next run; factory CI exercises the actual reusable workflow before merge.

[ADR 0001](/adr/0001-vector-first-mixed-rendering.md) owns mixed rendering. [ADR 0002](/adr/0002-separate-factory-and-consumers.md) owns repository boundaries. [ADR 0003](/adr/0003-build-artifacts-with-a-reusable-workflow.md) owns workflow and deployment responsibilities. [ADR 0004](/adr/0004-linked-game-cards.md) owns the measured fraction boundaries and game-link trust boundary. [ADR 0005](/adr/0005-preserve-low-alpha-soft-masks-as-raster.md) owns low-alpha raster preservation. [BDR 0002](/bdr/0002-reusable-workflow-build-contract.md) owns observable artifact behavior, [BDR 0005](/bdr/0005-fidelity-preserving-mixed-scene-output.md) owns source-independent mixed rendering and typed-link behavior, and [BDR 0006](/bdr/0006-expanded-freeform-graphics-output.md) owns the additional observed graphics state and affine image behavior.
