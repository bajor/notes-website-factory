---
type: PRD
title: Vector-first static site
description: Requirements for scalable artwork with raster screenshot preservation.
status: Accepted
timestamp: 2026-08-20
---
# Vector-First Static Site

## Problem

Rendering every Freeform image XObject as a raster asset preserves the export but becomes visibly pixelated under browser zoom. Reconstructing semantic Freeform objects is impossible because the source PDF contains rasterized artwork rather than original object geometry.

## Requirements

- Trace substantially transparent Freeform artwork into inline SVG paths.
- Preserve opaque and near-opaque screenshots and diagrams as raster assets.
- Fail when soft-mask evidence is too ambiguous for safe automatic classification.
- Preserve PDF source order, transforms, clips, opacity, links, and browser interactions.
- Emit no full-page raster, PDF, OCR output, Canvas fallback, or browser PDF parser.
- For the current source, emit 35 vector artwork nodes, 9 raster image nodes, and 9 raster assets.

## Quality Attributes

The generated browser scene must pass the existing error, tolerant-pixel, and ink thresholds at 18 DPI and 72 DPI. `make validate-dist` must reject a raster-only substitution by checking the mixed-scene counts and inline vector node tag.

## Acceptance

The requirement is accepted when all focused unit tests, `make test`, `make evaluate`, desktop interaction checks, and mobile interaction checks pass.
