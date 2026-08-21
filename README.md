# Algorithms for Slow Learners

This repository is a small Haskell software factory. It reads the repository's one-page Apple Freeform PDF, interprets its PDF drawing instructions, and generates a zoomable static website.

The project has two products:

- `dist/`, a browser-ready site made from JavaScript, inline SVG artwork, DOM overlays, and extracted raster assets;
- a readable example of functional programming, typed boundaries, and evidence-driven parser development.

The deployed browser never downloads or parses the PDF. Poppler is used only as a development oracle for visual comparison, not as the production renderer.

## Quick Start

Required versions:

- GHC 9.6.6;
- Cabal 3.10.3.0;
- `zlib1g-dev` for the PDF library;
- Poppler's `pdftoppm` and Chromium only for `make evaluate`;
- Python 3 only for `make serve`.

On Ubuntu, install the system libraries with:

```bash
sudo apt-get update
sudo apt-get install -y zlib1g-dev poppler-utils
```

Install Chromium or Chrome separately if the `chromium` command is unavailable. Set `CHROMIUM=/absolute/path/to/chrome` when the browser uses another command name.

Then run:

```bash
cabal update
make test
make evaluate
make serve
```

Open `http://localhost:8000`. `make serve` builds `dist/` before starting the local server.

## Factory Commands

| Command | Result |
| --- | --- |
| `make inspect` | Finds the only PDF and reports its page, operator, image, and link counts. |
| `make test` | Compiles with warnings as errors, runs unit tests, parses the real PDF, builds the site, and validates `dist/`. |
| `make build` | Generates the static site in `dist/`. Set `DIST=/path` to choose another output directory. |
| `make evaluate` | Rebuilds the site, compares it with Poppler's rendering, and writes evidence to `build/evaluation/`. |
| `make serve` | Serves `dist/` at `http://localhost:8000`. |

## Learn the Code in Order

1. Start with `generator/src/Factory/Domain.hs`. Domain types name coordinates, assets, links, scene nodes, and failures. The `Scene` phase parameter distinguishes `Scene 'Unvalidated` from `Scene 'Validated`.
2. Read `generator/src/Factory/Geometry.hs`. Every function is pure: the same matrix and point always produce the same result.
3. Read `generator/src/Factory/Interpreter.hs`. `foldM` implements an immutable state machine. Each PDF operator receives the old machine and returns either a typed error or a new machine.
4. Read `generator/src/Factory/Vectorize.hs`. It classifies embedded images and traces eligible Freeform artwork into deterministic SVG contours.
5. Read `generator/src/Factory/Pdf.hs`. This is the PDF effect boundary. `pdf-toolbox` reads objects and streams; this module converts them into the project's domain.
6. Read `generator/src/Factory/Site.hs`. Validation changes the scene's type before JavaScript can be emitted.
7. Read `generator/src/Factory/Pipeline.hs`. This is the imperative shell that discovers files, stages output, and connects the pure stages.
8. Read `generator/src/Factory/Evaluation.hs`. The parser's output is compared with a mature renderer at two resolutions so that visual errors become measurable evidence.

## Functional Programming Ideas

### Pure Core, Effectful Shell

Geometry, operator interpretation, image classification, contour tracing, URL classification, and scene validation do not choose files or mutate global state. File and process operations stay at the edges in `Factory.Pdf`, `Factory.Site`, `Factory.Evaluation`, and `Factory.Pipeline`.

This separation makes failures reproducible. A failing operator list can be passed directly to `interpretOperators` without opening a PDF or browser.

### Invalid States Become Hard to Express

PDF and browser coordinates use separate phantom types:

```haskell
pdfPointToBoard :: Coordinate PdfSpace -> Point PdfSpace -> Point BoardSpace
```

An unvalidated scene cannot be passed to the emitter:

```haskell
validateScene :: Scene 'Unvalidated -> Either BuildError (Scene 'Validated)
writeSite :: FilePath -> FilePath -> Scene 'Validated -> IO ()
```

The compiler enforces the order. Runtime validation still checks values that types alone cannot prove, including finite dimensions, valid opacities, known assets, and the prohibition on a full-board raster substitute.

### Errors Are Values

Expected failures use `Either BuildError value`. Missing resources, unsupported image formats, invalid graphics state, unsafe output paths, and failed evaluation do not require hidden exceptions to cross the functional core.

## AI Engineering Loop

Treat parser work as a measured loop rather than a one-shot generation prompt:

1. Inspect the source PDF and record objective facts.
2. Add the smallest domain type or operator transition needed by the evidence.
3. Add one focused unit test for that transition.
4. Run `make test` to prove compilation, unit behavior, real-PDF parsing, and deployable output.
5. Run `make evaluate` to compare the generated browser scene with Poppler's reference.
6. Inspect `build/evaluation/report.html` and both amplified difference images.
7. Repeat only where the evidence shows a gap.

The evaluator currently requires all of these conditions:

- mean normalized channel error at most `0.02`;
- at least `0.96` of pixels within the per-channel tolerance;
- generated/reference ink ratio from `0.85` through `1.15`;
- a browser DOM marked `data-ready="true"` after all image and font loads finish.

Each condition must pass at 18 DPI for the whole-board view and at 72 DPI for native PDF-point-scale detail.

## Input Contract

The repository must contain exactly one non-symlink PDF file, and that PDF must contain exactly one page. `Algos.pdf` is the current source.

The current implementation intentionally targets the observed Apple Freeform export profile:

- unrotated page with matching zero-origin MediaBox and CropBox;
- JPEG and 8-bit Flate image XObjects, including Flate soft masks;
- evidence-based image classification that preserves opaque and near-opaque screenshots as raster, traces substantially transparent Freeform artwork as SVG, and rejects ambiguous masks;
- axis-aligned image transforms;
- clipping paths, common color operators, and Freeform's opacity resources;
- HTTP and HTTPS URI annotations, including YouTube watch, short, and embed URLs;
- no text objects in the current source; text operators fail until font decoding and metrics are implemented.

Unsupported PDF operators or structures fail the build instead of being silently discarded. Known limitations are documented in `docs/pdf-investigation.md`.

## Generated Output

`make build` writes:

```text
dist/
|-- assets/
|-- index.html
|-- runtime.js
|-- scene.generated.js
|-- scene-summary.json
`-- styles.css
```

For the current `Algos.pdf`, the validated scene contains 35 inline SVG artwork nodes and 9 raster image nodes backed by exactly 9 files under `dist/assets/`. The output contains no PDF, OCR result, full-page screenshot, Rust bundle, TypeScript bundle, Node dependency, browser PDF parser, or server component. All references are relative so the site works under the GitHub Pages project path.

## Documentation

[`docs/index.md`](docs/index.md) indexes the architecture, observed PDF profile, requirements, decisions, behavior records, and implementation issues. Keep those records synchronized with structural or behavioral changes according to the strict living-docs policy in `AGENTS.md`.

## Deployment

`.github/workflows/pages.yml` builds `dist/` with GHC 9.6.6 and Cabal 3.10.3.0, then deploys it through the official GitHub Pages actions. Configure the repository's Pages source as **GitHub Actions**.

The PR-only architecture diagram cleanup uses the `REMOVE_VISUALS_MAIN` repository secret. The `bajor` user is the only bypass actor on the `require-pr-main` ruleset so that the cleanup commit can remove merged review artifacts.

Expected project URL:

```text
https://bajor.github.io/algos-for-slow-learners/
```

## Acceptance Criteria

Work is complete when `make test` and `make evaluate` pass, `dist/` contains the required mixed SVG/raster scene and no PDF, desktop and mobile browser interactions work, both evaluation resolutions pass, and the generated site can be deployed without Rust, Node, Poppler, Chromium, or Haskell at runtime.
