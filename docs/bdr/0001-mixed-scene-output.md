---
type: BDR
title: Mixed scene output
description: Observable classification, emission, rendering, and evaluation behavior.
status: Superseded
superseded_by: "0003"
timestamp: 2026-08-20
---
# Mixed Scene Output

## Behavior Flow

The [PR 5 review](https://github.com/bajor/notes-website-factory/pull/5/files) included a review-only flowchart showing source discovery, classification, interpretation, validation, SVG/raster emission, browser rendering, and the independent Poppler/Chromium feedback loop. The SVG was deleted from `main` after merge as designed.

## Scenarios

1. Given an image with no soft mask, when resources are prepared, then the image is preserved as raster.
2. Given a substantially transparent soft mask, when resources are prepared, then the image becomes vector artwork.
3. Given a soft mask in the ambiguity interval, when resources are prepared, then the build fails with `UnsupportedImage`.
4. Given mixed raster and vector `Do` operators, when the interpreter emits nodes, then their source order is unchanged.
5. Given the current repository PDF, when the site is built, then the summary reports 35 vector artworks, 9 raster images, and 9 raster assets.
6. Given the generated site, when Chromium renders at 18 and 72 DPI oracle scales, then each scale passes every configured visual threshold.

## Test Design

| Scenario | Instrument | Proof |
| --- | --- | --- |
| 1 | Unit test for `classifyImage Nothing` | Opaque resources stay raster. |
| 2 | Unit test with a transparent soft mask | Eligible artwork selects vector tracing. |
| 3 | Unit test with `0.006` transparent fraction | Ambiguity fails rather than guessing. |
| 4 | Interpreter unit test with raster then vector resources | Mixed nodes preserve order. |
| 5 | `make validate-dist` | Exact source-profile counts and vector node tag are present; Canvas is absent. |
| 6 | `make evaluate` and `build/evaluation/report.html` | Poppler and Chromium agree within thresholds at both resolutions. |

# References

1. [ADR 0001](/adr/0001-vector-first-mixed-rendering.md)
2. [Implementation issue 0001](/issues/0001-vector-first-rendering.md)
