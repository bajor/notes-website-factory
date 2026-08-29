---
type: Issue
title: Tile oversized visual evaluations
description: Keep 72 DPI visual gates reliable for boards beyond Chromium's single-viewport capture limit.
status: Done
timestamp: 2026-08-29
---
# Tile Oversized Visual Evaluations

## Scope

Implement [BDR 0007](/bdr/0007-tiled-visual-evaluation.md) without changing evaluation scales, thresholds, evidence filenames, or the reusable-workflow interface.

## Acceptance Criteria

- Capture planning covers the requested output exactly with bounded row-major tiles.
- Evaluation mode applies each tile's output-pixel origin without affecting normal interaction mode.
- Captured tiles are validated and stitched into the existing generated-image path.
- Focused planning, stitching, and runtime tests pass.
- `make test` and factory `make evaluate` pass.
- The motivating consumer passes 18 and 72 DPI evaluation through the reusable workflow.

## Plan

1. Record the bounded-capture architecture and observable behavior.
2. Add pure tile planning and stitching to `Factory.Evaluation`.
3. Add evaluation-only board offsets to the shared runtime.
4. Verify factory fixtures and the motivating consumer without changing visual policy.

## Completion

Factory pull request [#18](https://github.com/bajor/notes-website-factory-workflow/pull/18) delivered bounded capture and stitching. Consumer run [33277495889](https://github.com/bajor/notes-gcp/actions/runs/33277495889) passed before merge, and production run [33278070907](https://github.com/bajor/notes-gcp/actions/runs/33278070907) deployed the same source from `main`.

The accepted consumer metrics were:

| DPI | Mean error | Pixels within tolerance | Ink ratio |
| --- | --- | --- | --- |
| 18 | 0.00223946896487991 | 0.9921176074011082 | 1.0157885788047185 |
| 72 | 0.0016175143925352563 | 0.9945225345873541 | 1.034645959740838 |

The deployed site is [GCP DE](https://bajor.github.io/notes-gcp/), and its browser scene reports ready.

# References

1. [Tile capture decision](/adr/0006-tile-oversized-browser-evaluations.md)
2. [Tiled evaluation behavior](/bdr/0007-tiled-visual-evaluation.md)
3. [Expanded graphics requirements](/prd/0005-expanded-freeform-graphics.md)
