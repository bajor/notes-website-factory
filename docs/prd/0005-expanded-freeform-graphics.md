---
type: PRD
title: Expanded Freeform graphics fidelity
description: Requirements for preserving observed PDF path graphics state and affine embedded artwork.
status: Accepted
timestamp: 2026-08-28
---
# Expanded Freeform Graphics Fidelity

## Problem

A one-page Apple Freeform export can use the standard PDF `M`, `d`, `CS`, `SC`, `cs`, and `sc` operators and affine image matrices. The factory currently rejects those operators and non-axis-aligned artwork, so a valid consumer cannot complete site generation or visual evaluation.

## Goals

- Accept valid PDF miter-limit and dash-pattern operators.
- Resolve supported named path color spaces and preserve their component colors.
- Preserve the active path graphics state in emitted styles and browser SVG.
- Render complete affine matrices for raster and traced image resources.
- Keep unsupported stroke graphics-state features explicit.
- Retain the existing reusable workflow and evaluation thresholds.

## Non-Goals

- Supporting PDF line-cap or line-join operators.
- Supporting non-similarity transforms for stroked native paths.
- Ignoring unknown graphics-state operators.
- Applying general ICC color management or supporting complex color spaces.
- Adding consumer-specific values, resource names, dimensions, or workflow options.

## Requirements

1. The graphics-state interpreter must initialize the PDF miter limit to `10` and accept `M` values greater than or equal to `1`.
2. A value below `1` or a non-numeric operand must fail explicitly.
3. The interpreter must accept a `d` array containing nonnegative numbers when at least one element is positive, plus a numeric phase. An empty array denotes a solid line.
4. A dash array containing a negative number or only zeros must fail explicitly.
5. Each painted path must retain the active miter limit, dash array, and dash phase in its scene style.
6. A non-singular similarity transform on a stroked native path must scale line width, dash lengths, and dash phase uniformly while retaining the dimensionless miter limit. A non-similarity transform must fail explicitly.
7. Generated scene JSON and the browser runtime must map the active values to SVG `stroke-miterlimit`, `stroke-dasharray`, and `stroke-dashoffset` for stroked paths.
8. Named DeviceGray, DeviceRGB, DeviceCMYK, and one/three-component ICC-based resources must select the component count used by `SC` and `sc`, and selection must initialize the current color to that space's default.
9. Missing named color spaces, selected unsupported named color spaces, and component-count mismatches must fail explicitly. An unused unsupported declaration must not block generation.
10. Raster and vector artwork must use the complete affine PDF matrix after composition with browser image-row orientation.
11. Scene validation must reject non-finite or out-of-range graphics-state values and retain the full-board-raster prohibition by testing the board corners against transformed image bounds.
12. Factory and real-consumer evaluation must pass the existing 18 and 72 DPI thresholds without adjustment.

## Quality Attributes

| Attribute | Scenario | Instrument |
| --- | --- | --- |
| Fidelity | A supported source uses additional path state and affine artwork. Generated SVG preserves the path presentation and artwork placement. | Focused tests, real-consumer visual evaluation, and difference-image inspection. |
| Safety | A source supplies invalid stroke state or an unsupported named color space. The build fails instead of emitting an invalid style. | Focused tests and typed parser errors. |
| Compatibility | A source uses the previous profile. Existing defaults and axis-aligned output remain visually unchanged. | Synthetic fixture `make evaluate`. |
| Reusability | A consumer uses the observed behavior without a new input or source-specific rule. | Unchanged reusable-workflow invocation. |

## Acceptance

The capability is accepted when focused tests, `make test`, factory `make evaluate`, and the motivating consumer's 18 and 72 DPI evaluation pass without threshold or workflow-interface changes.

## Decision Log

- [BDR 0006](/bdr/0006-expanded-freeform-graphics-output.md) specifies observable parsing and rendering behavior.
- [Issue 0005](/issues/0005-support-expanded-freeform-graphics.md) tracks implementation and validation.

# References

1. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
2. [Observed source profile](/pdf-investigation.md)
