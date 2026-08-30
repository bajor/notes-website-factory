---
type: PRD
title: Opaque Freeform highlighters
description: Preserve low-alpha content except positively identified Freeform highlighter strokes.
status: Accepted
supersedes: "0004"
timestamp: 2026-08-29
---
# Opaque Freeform Highlighters

## Problem

The supported export contains an elongated yellow highlighter stroke whose soft-mask samples remain below the vector cutoff. Generic low-alpha preservation renders that marker translucent, while the requested product renders discovered Freeform highlighter lines as opaque.

## Requirements

1. Empty and all-zero masks must continue to fail, and masks with traceable samples must retain existing fraction boundaries.
2. Low-alpha content must remain a source-alpha raster unless it is positively classified as a highlighter stroke.
3. A highlighter stroke must be translucent, at least 95 percent chromatic among visible pixels, and at least four times longer than its shorter dimension.
4. Materialization must change each nonzero stroke alpha to `255` while preserving RGB, transparent pixels, geometry, transform, source order, and asset ownership.
5. The behavior must not depend on hue, resource name, consumer identity, or board dimensions.

## Acceptance

Focused positive and negative image tests pass, the observed elongated marker is opaque, compact colored content retains source alpha, and real-consumer evaluation evidence is reviewed without weakening thresholds.

# References

1. [Superseded low-alpha requirements](/prd/0004-low-alpha-soft-masks.md)
2. [Opaque highlighter decision](/adr/0009-opaque-highlighter-strokes.md)
3. [Opaque highlighter behavior](/bdr/0011-opaque-highlighter-output.md)
4. [Implementation issue](/issues/0009-render-highlighters-opaque.md)
