---
type: ADR
title: Preserve low-alpha soft masks as raster
description: Keep nonzero soft-mask content lossless when no sample is eligible for vector tracing.
status: Superseded
superseded_by: "0009"
timestamp: 2026-08-24
---
# Preserve Low-Alpha Soft Masks as Raster

## Context

The vector tracer ignores alpha samples below `96` and emits retained styles as opaque SVG fills. A new consumer export contains a soft-masked image whose samples are nonzero but all below that cutoff. Treating those samples as absent rejects content that a PDF renderer displays. Lowering the cutoff would instead turn faint pixels into opaque quantized paths.

The existing raster path already carries decoded alpha into `PixelRGBA8`, writes a lossless PNG, and lets Chromium composite the source alpha. The decision therefore concerns classification only.

## Decision

We will classify soft masks in this order:

1. Reject an empty mask.
2. Reject a mask whose samples are all zero.
3. Preserve a mask as raster when it has nonzero samples but none at or above alpha `96`.
4. For masks with at least one sample at or above alpha `96`, retain the existing fraction rules: at most `0.01` remains raster, above `0.01` and below `0.02` fails, and at least `0.02` is traced.

We will name alpha `96` the minimum traceable alpha, because lower samples can remain visibly significant even though the vector tracer cannot represent them faithfully.

## Rejected Alternatives

- Lower the tracing cutoff: current vector styles force retained pixels to full opacity, changing faint source content.
- Skip the resource: valid nonzero PDF content would disappear silently.
- Preserve every soft-masked resource as raster: this abandons the established vector-first output for traceable artwork.
- Preserve fully transparent masks: this weakens the explicit unsupported-content boundary without a visible source requirement.

## Consequences

Faint source pixels use the existing raster asset and browser composition path, so no domain, scene, runtime, workflow, or dependency change is required. The classifier gains one ordered branch and one clearer internal threshold name. Low-alpha assets remain pixel-based when zoomed, which is preferable to an opaque or omitted vector approximation.

The fitness functions are focused `classifyImage` tests and real-consumer visual evaluation at the unchanged 18 and 72 DPI thresholds.

## Verification

- `generator/src/Factory/Vectorize.hs` distinguishes source alpha from traceable alpha.
- Unit tests cover all-zero, low-nonzero, and exact-cutoff masks.
- Factory `make test` and `make evaluate` pass.
- The motivating consumer emits a raster asset and passes visual evaluation without threshold changes.

# References

1. [Low-alpha requirements](/prd/0004-low-alpha-soft-masks.md)
2. [Vector-first mixed rendering](/adr/0001-vector-first-mixed-rendering.md)
3. [Linked-card mask boundaries](/adr/0004-linked-game-cards.md)
4. [Fidelity-preserving mixed-scene behavior](/bdr/0005-fidelity-preserving-mixed-scene-output.md)
5. [Implementation issue](/issues/0004-preserve-low-alpha-soft-masks.md)
