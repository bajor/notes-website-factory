# Build a complete repository: single-page Freeform PDF → high-fidelity interactive zoomable website → GitHub Pages

Create a complete, production-quality GitHub repository implementing the system described below.

Do not just scaffold it. Implement it end-to-end, add tests, documentation, GitHub Actions, and make the repository usable immediately after cloning.

## Goal

I maintain my notes in Apple Freeform.

I export the Freeform board to exactly one PDF file:

```text
notes.pdf
```

The PDF is required to contain exactly one page.

That single PDF page represents the entire Freeform board.

The PDF may contain:

- text
- drawings
- handwritten notes
- arrows
- boxes
- images
- diagrams
- arbitrary Freeform shapes
- links
- YouTube links associated with visual regions/cards

I want `notes.pdf` to be the single source of truth.

My workflow must be:

```text
edit Apple Freeform board
        ↓
export as notes.pdf
        ↓
replace notes.pdf in Git repository
        ↓
open PR
        ↓
merge PR to main
        ↓
GitHub Actions automatically builds website
        ↓
GitHub Pages automatically publishes updated notes
```

The final website must visually reproduce the PDF extremely faithfully while providing a much better reading experience than a normal PDF viewer.

---

# Hard invariant: exactly one PDF page

The repository must enforce:

```text
./notes.pdf exists
AND
notes.pdf contains exactly 1 page
```

The build must fail if:

- `notes.pdf` is missing
- `notes.pdf` is invalid
- `notes.pdf` contains 0 pages
- `notes.pdf` contains more than 1 page

Example failure:

```text
ERROR: notes.pdf must contain exactly one page, found 3 pages
```

Do not support multi-page PDFs.

Do not silently concatenate pages.

Do not create page navigation.

The single page is one large spatial board.

---

# Core priorities

Priorities, in this exact order:

1. visual fidelity to `notes.pdf`
2. correctness of geometry and hyperlink placement
3. extremely smooth zooming and panning
4. fast loading
5. good mobile experience
6. working embedded YouTube videos
7. deterministic/reproducible builds
8. functional-programming-oriented generator architecture
9. minimal runtime JavaScript
10. maintainability

Do NOT reconstruct the PDF semantically into approximate HTML cards.

Do NOT attempt to infer that something is a Freeform rectangle, arrow, text box, etc. and recreate it using CSS.

The rendered PDF is the canonical visual representation.

---

# Architecture

Use this architecture unless actual implementation evidence demonstrates a clearly better solution:

```text
notes.pdf
   ↓
battle-tested PDF parser / renderer
   ↓
immutable Document model
   ↓
pure geometry + annotation transformations
   ↓
RenderPlan
   ↓
multi-resolution tile pyramid
   ↓
manifest.json
   ↓
small static TypeScript viewer
   ↓
GitHub Pages
```

The generator must follow a functional-core / imperative-shell design.

All parsing and rendering of PDF internals must be delegated to a mature, battle-tested PDF implementation.

Do NOT implement PDF parsing yourself.

Do NOT implement PDF rendering yourself.

---

# PDF implementation: battle-tested only

Use a mature, production-proven PDF engine/library.

Evaluate options such as:

- MuPDF
- PDFium
- Poppler

Prefer MuPDF if it satisfies the requirements cleanly.

The chosen implementation must support:

- reliable PDF page parsing
- MediaBox
- CropBox
- page rotation
- URI/link annotations
- annotation rectangles
- high-quality rendering
- deterministic CLI/library use on Linux
- arbitrary output resolution
- GitHub Actions compatibility
- reasonable licensing for an open-source GitHub project

Do not use an immature Rust-native PDF parser merely to keep everything in Rust.

It is acceptable and preferred to call a mature native PDF engine from the generator.

Example architecture:

```text
Rust
  ↓
thin adapter
  ↓
MuPDF / mutool
```

or a mature binding if substantially cleaner.

The PDF engine is responsible for understanding PDF.

Our program is responsible for deterministic transformation of its results.

Document the final choice and licensing implications.

---

# Generator language

Use Rust unless investigation reveals a concrete blocker.

Rust is preferred because it provides:

- algebraic data types
- immutable-by-default bindings
- enums with exhaustive matching
- explicit `Result` error handling
- strong types
- deterministic serialization
- excellent CLI tooling
- property-based testing support
- easy deployment as a native build tool

Do not choose Haskell or Scala merely to claim functional programming.

The important requirement is the programming model.

Use:

```text
functional core
+
imperative shell
```

---

# Functional programming requirements

The generator must be structured around pure transformations.

Conceptually:

```text
PDF metadata
    ↓
validateDocument
    ↓
DocumentGeometry
    ↓
extractRawAnnotations
    ↓
normalizeAnnotations
    ↓
classifyUrls
    ↓
RenderPlan
    ↓
SiteManifest
```

Functions such as:

```text
validate_page_count
normalize_rect
pdf_to_board_coordinates
classify_url
extract_youtube_id
build_render_plan
build_manifest
validate_manifest
```

should be pure wherever practical.

Prefer:

- immutable values
- iterator transformations
- explicit inputs and outputs
- no hidden global state
- no mutable shared state
- exhaustive enums
- typed domain objects
- deterministic ordering

Avoid:

- global mutable state
- hidden filesystem access
- environment reads inside business logic
- functions that both transform data and perform unrelated I/O
- large procedural functions

All I/O must live near explicit boundaries:

```text
read notes.pdf
invoke PDF engine
read PDF engine output
write tiles
write manifest
write static files
```

---

# Domain model

Create explicit types similar to:

```rust
struct PdfSize {
    width: f64,
    height: f64,
}

struct Rect {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

struct RawLinkAnnotation {
    rect: Rect,
    uri: String,
}

enum LinkKind {
    YouTube { video_id: String },
    ExternalUrl { url: String },
}

struct BoardLink {
    rect: Rect,
    kind: LinkKind,
}

struct Board {
    width: f64,
    height: f64,
    links: Vec<BoardLink>,
}
```

Use stronger types if useful.

Do not pass anonymous unstructured maps through the generator.

---

# Single-page geometry

The PDF contains exactly one board page.

Extract:

- MediaBox
- CropBox
- rotation
- effective width
- effective height

Correctly convert PDF annotation rectangles into board coordinates.

Handle the PDF coordinate system correctly.

PDF commonly uses bottom-left origin while browser/image coordinates use top-left origin.

The transformation must explicitly account for:

- CropBox offset
- MediaBox offset
- page rotation
- coordinate-axis inversion
- scaling
- renderer output dimensions

Do not spread coordinate conversion formulas throughout the code.

Implement one well-tested geometry layer.

---

# Property-based geometry testing

Use property-based tests for geometry where useful.

For example with `proptest`.

Test invariants such as:

```text
pdfRect
→ browserRect
→ inverseTransform
≈ original pdfRect
```

within floating-point tolerance.

Also test:

- rectangles remain normalized
- width >= 0
- height >= 0
- transformed rectangles preserve relative position
- known corner mappings are correct

This part is critical.

---

# Visual rendering strategy

Do NOT recreate PDF graphics using HTML.

Render the PDF page as a multi-resolution image pyramid.

Conceptually:

```text
large PDF page
       ↓
highest-resolution raster
       ↓
tile pyramid
       ↓
level 0
level 1
level 2
...
level N
```

The final browser experience should behave like a map viewer.

Only visible tiles should be requested.

Do not generate a single giant image that the browser must decode entirely.

---

# Tile viewer

Use a battle-tested tiled-image viewer rather than implementing complex zoom logic yourself.

OpenSeadragon is the preferred candidate.

Evaluate it and use it unless there is a concrete technical reason not to.

It should provide:

- tiled loading
- pan
- zoom
- desktop mouse interaction
- trackpad interaction
- touch pan
- pinch zoom
- image-space overlays

The application should use OpenSeadragon's coordinate system rather than manually updating overlay coordinates every frame.

Avoid application-level animation loops.

---

# Viewer technology

Do not use React unless required.

Prefer:

```text
TypeScript
Vite or equivalent minimal bundler
OpenSeadragon
small CSS file
```

The runtime application should be very small.

No:

- Next.js
- Redux
- large component libraries
- Tailwind dependency unless clearly justified
- server-side runtime

This is a static viewer, not a web application framework problem.

---

# PDF tile rendering

Determine an appropriate highest-resolution render.

Expose configuration such as:

```text
MAX_RENDER_DPI
TILE_SIZE
IMAGE_FORMAT
IMAGE_QUALITY
```

Good defaults should prioritize note readability.

Thin handwriting, diagrams and small text matter.

Evaluate formats such as:

- WebP lossless
- WebP high quality
- PNG
- AVIF

Do not automatically choose JPEG.

Run a small comparison and document the decision.

The output must not visibly destroy thin text or handwriting.

---

# Deep Zoom compatibility

If using OpenSeadragon, generate either:

- standard Deep Zoom Image (`.dzi`) metadata and tile hierarchy
- another directly supported tiled image source

Prefer a standard format rather than inventing a proprietary tile protocol.

For example:

```text
dist/
  board.dzi
  board_files/
    0/
    1/
    2/
    ...
```

if DZI is selected.

---

# YouTube links: critical requirement

The Freeform PDF export may not contain a real video object.

It may instead contain:

```text
visual thumbnail/card
+
PDF URI hyperlink annotation
```

Therefore inspect PDF annotations directly.

For every URI annotation extract:

```text
x
y
width
height
URI
```

Do not infer URLs from pixels.

Do not use OCR.

Do not use AI.

Do not scrape external services.

---

# YouTube URL recognition

Recognize at least:

```text
https://youtube.com/watch?v=...
https://www.youtube.com/watch?v=...
https://m.youtube.com/watch?v=...
https://youtu.be/...
https://youtube.com/shorts/...
https://www.youtube.com/shorts/...
https://youtube.com/embed/...
https://www.youtube.com/embed/...
```

Create a pure function:

```text
parseYouTubeUrl(url) -> Option<VideoId>
```

or Rust equivalent.

Normalize valid YouTube links into canonical video IDs.

Test:

- watch URLs
- shortened URLs
- Shorts
- embed URLs
- additional query parameters
- timestamps
- malformed URLs
- deceptive non-YouTube domains

For example:

```text
youtube.com.evil.example
```

must NOT be accepted as YouTube.

Parse URLs structurally.

Do not classify via naive substring checks.

---

# URL security

Only accept explicitly supported URI schemes.

For normal external links support:

```text
https:
http:
```

Optionally support:

```text
mailto:
```

only if implemented explicitly.

Reject:

```text
javascript:
data:
file:
vbscript:
```

and unknown dangerous schemes.

URL classification must be a pure function with tests.

---

# Overlay model

Generate a manifest:

```json
{
  "version": 1,
  "board": {
    "width": 12345.67,
    "height": 9876.54
  },
  "links": [
    {
      "x": 123.4,
      "y": 567.8,
      "width": 800.0,
      "height": 450.0,
      "kind": "youtube",
      "videoId": "abc123"
    }
  ]
}
```

Coordinates must use one documented canonical board coordinate system.

Sort data deterministically before serialization.

Do not rely on hash-map iteration order.

---

# YouTube overlays

At runtime place an overlay over the exact PDF link rectangle.

The board underneath remains the canonical visual.

Before interaction:

```text
PDF-rendered YouTube preview remains visible
```

Do NOT eagerly instantiate YouTube iframe players.

When the user activates a YouTube region, replace or cover that visual region with:

```text
https://www.youtube-nocookie.com/embed/<VIDEO_ID>
```

The iframe must:

- stay exactly registered with the PDF region
- move correctly when panning
- scale correctly while zooming
- remain interactive
- work on iPhone Safari
- not autoplay by default

Only instantiate players that the user activates.

If there are 100 YouTube links, initial page load should not create 100 iframe elements.

---

# Non-YouTube links

Make ordinary URI annotations clickable.

They must stay geometrically aligned with their source region.

Open external URLs safely using:

```text
target="_blank"
rel="noopener noreferrer"
```

or equivalent programmatic behavior.

Pointer handling must not ruin panning.

A drag beginning over a link region should not accidentally navigate.

Differentiate click/tap from drag.

---

# Critical Apple Freeform limitation

Do not assume every visually displayed YouTube card will have a URL annotation.

If the exported PDF contains:

```text
YouTube-looking image
```

but no URI annotation, then the original URL cannot be deterministically recovered from the PDF graphics alone.

In this situation:

- preserve the graphics
- report the limitation
- do not guess the URL
- do not use OCR
- do not use image recognition
- do not use external APIs

The generator must remain deterministic.

---

# Inspect command

Implement:

```bash
make inspect
```

or:

```bash
notes-site inspect notes.pdf
```

It must inspect the actual PDF and print something like:

```text
File: notes.pdf
Pages: 1

Page:
  MediaBox: ...
  CropBox: ...
  Rotation: 0
  Effective size: 12400 x 9300 pt

URI annotations: 12
YouTube annotations: 7
External links: 5

Links:
  [youtube] rect=(...) videoId=...
  [url] rect=(...) url=https://...
```

If pages != 1:

```text
ERROR: expected exactly one page, found N
```

and exit non-zero.

---

# Determinism

For identical:

```text
notes.pdf
generator version
PDF renderer version
configuration
```

the generated output should be reproducible.

Requirements:

- stable JSON ordering
- stable manifest ordering
- no generated timestamps inside build artifacts unless necessary
- no random IDs
- no nondeterministic filenames
- pinned major/minor versions where appropriate
- deterministic tile naming
- explicit rendering parameters

Create a content/build identity based on SHA-256 of relevant inputs if useful.

---

# Repository structure

Use a structure similar to:

```text
/
├── notes.pdf
├── README.md
├── Makefile
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── pages.yml
├── generator/
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── domain.rs
│   │   ├── geometry.rs
│   │   ├── links.rs
│   │   ├── manifest.rs
│   │   ├── pdf_adapter.rs
│   │   └── render.rs
│   └── tests/
├── viewer/
│   ├── package.json
│   ├── src/
│   └── ...
├── scripts/
├── docs/
│   ├── architecture.md
│   └── pdf-investigation.md
└── dist/
```

Adjust if a cleaner structure emerges.

---

# Imperative shell boundary

Keep PDF engine interaction isolated.

For example:

```text
pdf_adapter.rs
```

may:

- invoke `mutool`
- parse its structured output
- call rendering commands

But geometry, URL parsing, annotation classification, manifest construction and validation must not call external processes.

The codebase should make it obvious where effects occur.

---

# PDF adapter

If the battle-tested PDF tool can emit structured machine-readable metadata, use it.

Prefer structured formats over scraping human-readable CLI output.

If a small mature binding is available and reliable, evaluate it.

Do not write a custom PDF token/object/xref parser.

That is explicitly out of scope.

---

# Integration fixture

Create a small test PDF fixture containing:

- one page
- text
- visible rectangle
- normal HTTPS link annotation
- YouTube link annotation

Prefer generating the fixture programmatically during tests or keeping a tiny deterministic fixture in the repository.

Test the complete extraction pipeline against it.

---

# Invalid multi-page fixture

Also create/test a PDF containing at least 2 pages.

The generator must reject it.

Test expected behavior:

```text
exit status != 0
stderr contains:
"expected exactly one page"
```

---

# Visual regression

Add a visual rendering regression test.

Render the fixture PDF and compare against a known reference or use a deterministic perceptual/pixel validation strategy.

The goal is to detect:

- wrong page size
- clipping
- broken renderer invocation
- gross visual differences

Use a sensible tolerance if exact pixels differ across renderer versions.

Pinning the renderer version is preferable.

---

# Generator tests

At minimum cover:

## Document validation

```text
0 pages -> fail
1 page -> success
2+ pages -> fail
```

## Geometry

- MediaBox offsets
- CropBox offsets
- page rotation
- top-left/bottom-left conversion
- scale transforms
- rectangles at each page corner

## URLs

- all supported YouTube formats
- invalid IDs
- fake domains
- normal HTTPS
- unsafe URI schemes

## Manifest

- stable serialization
- stable sort order
- valid bounds
- positive board dimensions

## Rendering plan

- pyramid levels
- tile boundaries
- edge tiles
- exact board dimensions

---

# Local commands

Provide:

```bash
make inspect
```

Inspect `notes.pdf`.

```bash
make test
```

Run all Rust and viewer tests.

```bash
make build
```

Produce the complete static site under:

```text
dist/
```

```bash
make serve
```

Build if necessary and run a simple local static HTTP server.

These commands must actually work.

---

# Build output

A successful build should resemble:

```text
dist/
├── index.html
├── assets/
├── manifest.json
├── board.dzi
└── board_files/
    ├── 0/
    ├── 1/
    ├── 2/
    └── ...
```

Exact layout can differ if technically justified.

The browser must never need access to `notes.pdf`.

---

# PR CI

On pull requests affecting relevant files:

1. install exact required PDF engine
2. validate `notes.pdf`
3. verify exactly one page
4. compile generator
5. run Rust tests
6. run viewer tests
7. run full build
8. validate generated output
9. fail if anything is inconsistent

Most importantly:

If I accidentally export a multi-page PDF, CI must reject the PR.

---

# GitHub Pages deployment

On push/merge to:

```text
main
```

run the complete build and deploy `dist/`.

Use the official current GitHub Pages Actions approach:

```text
actions/configure-pages
actions/upload-pages-artifact
actions/deploy-pages
```

Use appropriate permissions:

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

Configure the GitHub Pages deployment environment properly.

Do not maintain a manually committed `gh-pages` branch.

---

# GitHub Pages path handling

The static viewer must work at both:

```text
https://USER.github.io/
```

and:

```text
https://USER.github.io/REPOSITORY/
```

No hardcoded root-relative paths such as:

```text
/assets/foo.js
```

unless the configured base path makes them correct.

Test repository subpath deployment.

---

# Runtime performance

The board may be very large.

Runtime performance is critical.

Requirements:

- tiles loaded on demand
- low initial network usage
- low DOM count
- no PDF parsing in browser
- no massive raster decoded upfront
- no per-frame application state rerendering
- use compositor-friendly transforms
- avoid expensive JS during pan/zoom
- lazy YouTube players
- preload only sensible nearby tiles

The experience should resemble a map viewer.

---

# Mobile behavior

iPhone Safari is a primary target.

Requirements:

- one-finger drag pans
- pinch zoom works
- no accidental whole-page scrolling while manipulating board
- no browser zoom interference where avoidable
- YouTube iframe remains operable after activation
- tap links reliably
- safe-area-aware minimal controls
- correct viewport metadata

Test responsive behavior using phone-sized browser tests where practical.

---

# Viewer UI

Keep UI minimal.

Provide:

- zoom in
- zoom out
- fit board
- reset view
- optional fullscreen

Keyboard:

```text
+  zoom in
-  zoom out
0  fit board
f  fullscreen
```

No page controls because the PDF is required to be one page.

---

# Initial view

On first load:

```text
fit entire board
```

or use another clearly justified default.

Do not immediately load maximum-resolution tiles.

Optionally persist the last viewport in `localStorage`.

If the manifest/build identity changes because `notes.pdf` changed, old viewport state may be reset if appropriate.

---

# Build statistics

Print a concise summary after build:

```text
Input PDF:              14.2 MiB
Pages:                  1
Board size:             13240 × 8820 pt
URI annotations:        23
YouTube annotations:    11
Tile levels:            8
Generated tiles:        842
Output size:            96.3 MiB
Manifest size:          8.2 KiB
```

Do not make timing a reproducibility requirement.

---

# Architecture documentation

Create:

```text
docs/architecture.md
```

Explain concretely:

1. selected battle-tested PDF engine
2. why custom PDF parsing is forbidden
3. why the generator uses Rust
4. functional-core / imperative-shell structure
5. domain model
6. coordinate conversion
7. tile-pyramid strategy
8. OpenSeadragon choice
9. YouTube overlay behavior
10. lazy iframe strategy
11. deterministic build guarantees
12. GitHub Pages deployment
13. PDF engine licensing
14. Apple Freeform PDF limitations

Do not fill it with generic software-engineering prose.

---

# README workflow

The beginning of README should make the normal workflow obvious:

```text
1. Export Apple Freeform board as PDF.
2. Ensure the export consists of exactly one PDF page.
3. Replace ./notes.pdf.
4. Commit and open a PR.
5. CI validates and builds it.
6. Merge to main.
7. GitHub Pages updates automatically.
```

Then show:

```bash
make inspect
make test
make build
make serve
```

---

# Error handling

Use explicit typed errors.

Examples:

```text
MissingNotesPdf
InvalidPdf
UnexpectedPageCount { found: usize }
InvalidPageGeometry
InvalidAnnotationRectangle
PdfRendererFailure
UnsafeUrl
TileGenerationFailure
ManifestValidationFailure
```

CLI output should be understandable.

Do not panic for normal validation failures.

---

# Do not do these

Do NOT:

- implement a PDF parser
- implement a PDF renderer
- use an immature PDF parser for ideological language purity
- support multiple pages
- concatenate pages
- use browser PDF rendering
- embed `notes.pdf` directly
- rebuild Freeform objects as HTML
- use OCR
- use computer vision
- use an LLM at build time
- use a backend
- eagerly instantiate YouTube iframes
- render one gigantic browser image
- introduce React without clear justification
- use mutable global state in the generator
- mix process/filesystem I/O into pure transformation code
- silently accept malformed annotations

---

# Development strategy

Work iteratively but complete the implementation.

Start with:

```text
notes.pdf
    ↓
page-count validation
    ↓
metadata inspection
    ↓
URI extraction
    ↓
one high-quality render
    ↓
tile pyramid
    ↓
manifest
    ↓
minimal OpenSeadragon viewer
    ↓
URL overlay
    ↓
YouTube lazy iframe
```

Then add:

- tests
- property tests
- visual regression
- CI
- GitHub Pages
- documentation
- performance validation

Run the actual commands.

Do not stop at writing code.

Fix compilation errors.

Fix tests.

Build the site.

Inspect generated output.

---

# Definition of done

The repository is complete only if:

```bash
make inspect
make test
make build
make serve
```

all work.

Additionally:

- `notes.pdf` with exactly one page succeeds
- a multi-page PDF fails immediately
- output visually matches the PDF
- pan/zoom is smooth
- tiles are loaded lazily
- ordinary hyperlinks work
- YouTube links appear at correct locations
- YouTube iframe is instantiated only after user action
- desktop works
- iPhone-sized viewport works
- no backend exists
- browser does not parse PDF
- build is deterministic
- PR CI rejects invalid PDFs
- merge to `main` deploys automatically to GitHub Pages

My routine maintenance must consist only of:

```text
replace notes.pdf
commit
merge
```

Everything else must be automatic.

---

# Final instruction

Do not ask me to pick libraries unless there is a genuine blocker.

Make technically justified choices.

Use a battle-tested PDF parser/renderer.

Keep PDF handling behind a narrow adapter.

Implement the transformation logic using a strongly typed functional core.

Prioritize correctness of visual reproduction, annotation geometry, deterministic behavior and runtime performance over minimizing implementation effort.
