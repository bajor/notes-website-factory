---
type: PRD
title: Low-alpha soft-mask fidelity
description: Requirements for preserving faint PDF image content that the vector tracer cannot represent.
status: Accepted
timestamp: 2026-08-24
---
# Low-Alpha Soft-Mask Fidelity

## Problem

An Apple Freeform export can contain an image whose soft mask has nonzero opacity but no sample reaches the vector tracer's alpha cutoff. PDF renderers display this faint content, while the factory currently reports that the mask contains no visible artwork and rejects the complete document.

## Goals

- Preserve nonzero source pixels when vector tracing would discard every pixel.
- Keep the existing near-opaque raster boundary, ambiguity interval, and vector boundary for masks that contain traceable samples.
- Retain explicit failure for empty or fully transparent masks.
- Preserve the existing workflow, scene, runtime, and evaluation contracts.

## Non-Goals

- Lowering the vector tracer's alpha cutoff.
- Adding alpha-aware SVG contour tracing.
- Ignoring image resources that contain source content.
- Accepting soft-mask formats outside the documented Apple Freeform profile.
- Adding consumer-specific resource names, dimensions, or thresholds.

## Requirements

1. A non-empty soft mask containing at least one nonzero sample but no sample at or above alpha `96` must remain a raster asset.
2. An empty or all-zero soft mask must still fail explicitly.
3. A mask containing a sample at or above alpha `96` must continue through the existing non-opaque-fraction classifier.
4. Raster materialization must retain the decoded per-pixel alpha values.
5. Factory and real-consumer evaluation must pass the existing 18 and 72 DPI thresholds without adjustment.

## Quality Attributes

| Attribute | Scenario | Instrument |
| --- | --- | --- |
| Fidelity | A supported source contains faint nonzero image pixels below the tracing cutoff. The generated browser product retains those pixels. | Real-consumer `make evaluate` and difference-image inspection at 18 and 72 DPI. |
| Safety | A soft mask is empty or fully transparent. The build fails instead of silently omitting a resource. | Focused `classifyImage` unit tests. |
| Compatibility | A source mask contains traceable samples. Existing fraction boundaries select raster, rejection, or vector output unchanged. | Existing boundary tests plus an inclusive alpha-cutoff test. |
| Reusability | A consumer uses the new behavior without naming a resource or configuring a threshold. | Consumer-path inspection through the unchanged reusable workflow. |

## Success Metrics

- The motivating consumer completes inspection and visual evaluation with unchanged thresholds.
- Empty and all-zero mask regression tests continue to return `UnsupportedImage`.
- The reusable workflow interface and generated scene schema have zero changes.

## Acceptance

The capability is accepted when focused tests prove the ordered mask behavior, factory gates pass, the motivating consumer retains the low-alpha image as a PNG, and its 18 and 72 DPI report passes without threshold changes.

## Decision Log

- [ADR 0005](/adr/0005-preserve-low-alpha-soft-masks-as-raster.md) selects lossless raster preservation.
- [BDR 0005](/bdr/0005-fidelity-preserving-mixed-scene-output.md) specifies the observable classification order.
- [Issue 0004](/issues/0004-preserve-low-alpha-soft-masks.md) tracks implementation and validation.

# References

1. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
2. [Interactive game-link requirements](/prd/0003-interactive-game-links.md)
3. [Observed source profile](/pdf-investigation.md)
