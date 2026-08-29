---
type: ADR
title: Tile oversized browser evaluations
description: Capture bounded Chromium viewports and stitch them before visual comparison.
status: Accepted
timestamp: 2026-08-29
tags: [evaluation, reliability]
---
# Tile Oversized Browser Evaluations

## Context

The motivating consumer's 72 DPI output is 24,204 by 12,080 pixels. Chromium returns a valid but blank PNG when asked to capture that complete viewport, even though the same generated scene passes at 18 DPI. A visual gate cannot distinguish this browser capture limit from missing generated content.

## Decision

`Factory.Evaluation` reads reference dimensions from the PNG header and divides any browser output larger than 8,192 by 4,096 pixels into a deterministic grid. The runtime translates the board by each tile's output-pixel origin, Chromium captures one bounded viewport at a time, and the evaluator copies one decoded tile at a time into the existing `generated-<dpi>.png` before applying the unchanged metrics and thresholds.

The tile files live in a hidden temporary report subdirectory that is removed after handled success or failure and excluded from uploaded evidence after abrupt process termination. The report filenames, 18 and 72 DPI scales, and reusable-workflow interface remain unchanged.

## Consequences

- Browser capture and tile-decoding memory are bounded independently of source dimensions.
- Oversized evaluations require multiple Chromium processes and therefore take longer.
- The evaluator owns deterministic tile planning and stitching; the runtime owns only the evaluation offset.

## Rejected Alternatives

- Cap evaluation below 72 DPI: weakens the accepted fidelity contract and no longer tests the requested scale.
- Use a larger GitHub Actions runner: increases cost without removing Chromium's single-surface dimension limit.
- Raise or bypass the ink threshold for large boards: would convert a capture failure into a false pass.

# References

1. [Expanded graphics requirements](/prd/0005-expanded-freeform-graphics.md)
2. [Tiled evaluation behavior](/bdr/0007-tiled-visual-evaluation.md)
3. [Implementation issue](/issues/0006-tile-oversized-visual-evaluations.md)
