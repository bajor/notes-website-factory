---
type: ADR
title: Render recognized highlighter strokes as opaque
description: Add a narrow geometry-and-chroma exception to low-alpha raster preservation.
status: Accepted
supersedes: "0005"
timestamp: 2026-08-29
---
# Render Recognized Highlighter Strokes as Opaque

## Context

The user explicitly requested opaque output when the factory discovers a Freeform highlighter line. The observed long yellow resource is low-alpha and therefore follows the generic lossless raster path selected by ADR 0005.

## Decision

`Factory.Vectorize.opaqueHighlighter` profiles decoded RGBA pixels before raster materialization. A translucent image qualifies only when at least 95 percent of visible pixels are chromatic and its aspect ratio is at least `4:1`. Qualified nonzero pixels receive alpha `255`; zero-alpha pixels and RGB channels remain unchanged. Other low-alpha resources retain source alpha.

## Rejected Alternatives

- Preserve marker alpha: this rejects the requested appearance.
- Make every chromatic raster opaque: compact cards and colored diagrams would be misclassified.
- Apply CSS opacity: asset identity is unavailable to the generic browser renderer.
- Name the observed resource: names are consumer-specific and unstable.

## Consequences

Highlighter appearance intentionally differs from the PDF reference, so evaluation differences require inspection rather than threshold weakening. The rule remains pure, source-independent, and limited to opacity.

# References

1. [Current requirements](/prd/0008-opaque-freeform-highlighters.md)
2. [Superseded decision](/adr/0005-preserve-low-alpha-soft-masks-as-raster.md)
3. [Current behavior](/bdr/0011-opaque-highlighter-output.md)
4. [Implementation issue](/issues/0009-render-highlighters-opaque.md)
