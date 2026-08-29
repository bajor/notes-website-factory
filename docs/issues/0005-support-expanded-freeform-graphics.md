---
type: Issue
title: Support expanded Freeform graphics
description: Preserve observed PDF path state and affine artwork, then validate the motivating consumer.
status: Done
timestamp: 2026-08-28
---
# Support Expanded Freeform Graphics

## Scope

Implement [BDR 0006](/bdr/0006-expanded-freeform-graphics-output.md) without adding a workflow input, consumer-specific rule, or unrelated PDF features.

## Acceptance Criteria

- Valid `M` operands update the immutable graphics state.
- Valid `d` operands update the immutable graphics state.
- Invalid miter limits and dash arrays fail explicitly.
- Path styles, scene JSON, and stroked SVG paths preserve the active values.
- Similarity transforms scale native stroke metrics, while non-similarity stroke transforms fail explicitly.
- Supported named path color spaces preserve stroke and fill colors.
- Selecting a supported color space initializes its current color.
- Unsupported named color spaces fail when selected, not merely when declared.
- Raster and traced image resources preserve complete affine transforms.
- Focused tests, `make test`, and factory `make evaluate` pass.
- The motivating consumer passes 18 and 72 DPI evaluation through the reusable workflow.

## Plan

1. Record the expanded graphics contract and supported-profile observation.
2. Carry path state through resources, `GraphicsState`, `PaintStyle`, JSON, validation, and the runtime.
3. Replace axis-aligned artwork layout with the complete affine presentation matrix.
4. Run factory and real-consumer visual gates without changing thresholds.
5. Merge the factory change and rerun the consumer against factory `main`.

## Completion

Factory pull requests [#16](https://github.com/bajor/notes-website-factory-workflow/pull/16) and [#17](https://github.com/bajor/notes-website-factory-workflow/pull/17) delivered the graphics and large-board compositor support. [Issue 0006](/issues/0006-tile-oversized-visual-evaluations.md) records the final 18 and 72 DPI consumer acceptance and production deployment that complete this issue's last criterion.

# References

1. [Expanded graphics requirements](/prd/0005-expanded-freeform-graphics.md)
2. [Expanded graphics behavior](/bdr/0006-expanded-freeform-graphics-output.md)
