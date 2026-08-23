# Notes Website Factory

This repository provides a reusable GitHub Actions workflow that converts one-page Apple Freeform PDFs into responsive, zoomable static websites. Consumer repositories provide one PDF and a site title. The factory owns the Haskell parser, shared viewer, visual evaluation, and Pages artifact production.

The deployed browser never downloads or parses the PDF. It receives JavaScript scene data, inline SVG artwork, DOM overlays, and extracted raster assets. Poppler and Chromium are development or CI evaluation tools, not runtime dependencies.

## Consumer Contract

A consumer repository must contain exactly one non-symlink PDF. The PDF must contain exactly one page and use the supported Apple Freeform export profile documented in [`docs/pdf-investigation.md`](docs/pdf-investigation.md).

The caller supplies one required workflow input:

| Input | Meaning |
| --- | --- |
| `site-title` | Non-empty browser title. The factory also derives the viewer's accessible name from it. |

The reusable workflow produces two artifacts:

| Artifact | Meaning |
| --- | --- |
| `github-pages` | Validated static website ready for `actions/deploy-pages`. |
| `pdf-site-evaluation` | Poppler references, Chromium screenshots, difference images, metrics, and `report.html`. |

The workflow intentionally does not deploy. Each consumer owns its branch trigger, permissions, environment protection, concurrency, and Pages deployment.

## Consumer Workflow

Configure the consumer repository's Pages source as **GitHub Actions**, then create `.github/workflows/pages.yml`:

```yaml
name: Publish Notes

on:
  pull_request:
  push:
    branches: [main]

permissions: {}

concurrency:
  group: pages-${{ github.ref }}
  cancel-in-progress: false

jobs:
  build:
    permissions:
      contents: read
    uses: bajor/notes-website-factory/.github/workflows/build-pdf-site.yml@main
    with:
      site-title: My Notes

  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5
      - id: deployment
        uses: actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e # v4
```

Pull requests build and evaluate the site without deploying. A push to `main`, including a merged pull request, deploys only after the reusable build succeeds.

The example intentionally references `@main`. This makes every new run use the latest factory commit. The workflow checks out its implementation through `job.workflow_sha`, so a run always uses generator source from the exact commit that supplied the workflow file. Consumers that require immutable behavior may replace `main` with a full commit SHA.

## Input Scope

The workflow is reusable across different board dimensions, filenames, repositories, resource names, and mixed-scene counts. It does not assume a specific page title, URL, number of images, or number of vector nodes.

The parser remains intentionally limited to the observed Apple Freeform profile:

- unrotated pages with matching zero-origin MediaBox and CropBox;
- JPEG and 8-bit Flate image XObjects, including Flate soft masks;
- axis-aligned image transforms;
- clipping paths, common color operators, and Freeform opacity resources;
- HTTP and HTTPS URI annotations, including supported YouTube URLs and exact HTTPS Algo Arcade game routes;
- no PDF text until font decoding and metrics are implemented.

Unsupported operators or structures fail explicitly. A caller never receives a partially rendered Pages artifact.

## Generated Product

The `github-pages` artifact contains:

```text
site/
|-- assets/                 # Present only when raster assets are required.
|-- index.html
|-- runtime.js
|-- scene.generated.js
|-- scene-summary.json
`-- styles.css
```

The product contains no PDF, OCR output, full-page PDF raster, Canvas fallback, browser PDF parser, backend, Rust bundle, TypeScript bundle, or Node dependency. Relative resource references allow deployment under any GitHub Pages project path. YouTube annotations activate privacy-enhanced video embeds. An annotation matching `https://bajor.github.io/algo-arcade/#/games/<game>` remains a native new-tab link and receives a gamepad badge in the interactive viewer.

## Local Development

Required versions:

- GHC 9.6.6;
- Cabal 3.10.3.0;
- `zlib1g-dev`;
- Poppler and Chromium for visual evaluation;
- Python 3 only for `make serve`.

Run the factory's synthetic one-page fixture:

```bash
make test
make evaluate
make serve
```

Build another supported source directory explicitly:

```bash
make evaluate \
  SOURCE=/absolute/path/to/consumer \
  DIST=/absolute/path/to/output/site \
  REPORT=/absolute/path/to/output/evaluation \
  SITE_TITLE='My Notes'
```

`SOURCE` must contain exactly one PDF. `TEMPLATES` defaults to this repository's `site/` directory. Output and evaluation paths must be non-symlink, non-overlapping paths outside the source and templates; the factory validates them before any removable directory is reset.

## Quality Gates

`make test` compiles with warnings as errors, runs focused unit tests, parses the synthetic fixture, builds a generic vector-only site, and validates its distribution. `make evaluate` additionally compares Poppler and Chromium at 18 and 72 DPI and runs a synthetic link-runtime smoke test. Evaluation mode omits the synthesized gamepad badge so the comparison measures PDF-derived content only.

The evaluator requires:

- mean normalized channel error at most `0.02`;
- at least `0.96` of pixels within per-channel tolerance;
- generated/reference ink ratio from `0.85` through `1.15`;
- a browser DOM marked `data-ready="true"` after assets and fonts load.

Factory CI invokes the reusable workflow against the fixture. This tests the same isolated consumer/factory checkout topology used by external repositories.

## Code Map

1. `Factory.Domain` owns shared types and invalid-state prevention.
2. `Factory.Geometry` owns coordinate and affine matrix math.
3. `Factory.Interpreter` owns the immutable PDF operator state machine.
4. `Factory.Vectorize` owns image classification and contour tracing.
5. `Factory.Pdf` owns the `pdf-toolbox` boundary and asset materialization.
6. `Factory.Site` validates scenes and emits the static product.
7. `Factory.Pipeline` separates source, template, output, and report paths.
8. `Factory.Evaluation` owns the Poppler/Chromium comparison.
9. `site/` owns the shared responsive viewer.
10. `.github/workflows/build-pdf-site.yml` owns reusable orchestration and artifact upload.

[`docs/index.md`](docs/index.md) indexes the architecture, supported profile, requirements, decisions, behavior records, and implementation issues.

## Acceptance Criteria

The factory is healthy when `make test` and `make evaluate` pass, CI proves the reusable workflow against the fixture, supported consumer PDFs produce visually validated Pages artifacts, recognized game links expose an accessible click affordance on desktop and mobile, unsupported input fails explicitly, and no consumer-specific content or deployment policy is required by the factory.
