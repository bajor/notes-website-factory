---
type: PRD
title: Interactive Algo Arcade game links
description: Requirements for accepting near-opaque linked cards and marking exact game routes without weakening PDF fidelity.
status: Accepted
timestamp: 2026-08-23
---
# Interactive Algo Arcade Game Links

## Problem

A refreshed consumer PDF contains two linked cards whose rounded soft masks have slightly more non-opaque edge samples than the previous safe-raster boundary. The same PDF introduces an Algo Arcade URI annotation. The existing classifier rejects the first card, and generic external-link rendering provides no game-specific click affordance.

## Goals

- Accept the observed near-opaque linked cards as raster without classifying ambiguous masks silently.
- Recognize only structurally valid Algo Arcade game routes as typed game links.
- Show an accessible gamepad affordance that opens the original game in its website.
- Preserve existing YouTube embeds, ordinary external links, and PDF-fidelity evaluation.

## Non-Goals

- Embedding remote games in iframes.
- Treating every GitHub Pages URL or every `bajor.github.io` page as a game.
- Adding a caller-configurable host allowlist or image threshold.
- Retaining the production PDF in the factory fixture.

## Requirements

- A soft mask with at most `0.01` non-opaque samples is near-opaque raster content.
- A soft mask above `0.01` and below `0.02` fails as ambiguous.
- A soft mask with at least `0.02` non-opaque samples is eligible for vector tracing.
- A game target requires HTTPS, exact host `bajor.github.io`, no credentials or explicit port, exact path `/algo-arcade/`, and a non-empty fragment beginning `#/games/`.
- A recognized game target serializes separately from YouTube and generic external targets.
- The normal viewer renders a gamepad badge and a native anchor with an accessible label, `_blank`, and `noopener noreferrer`.
- Evaluation mode omits the badge while retaining the source annotation bounds.

## Quality Attributes

| Attribute | Scenario | Instrument |
| --- | --- | --- |
| Safety | A deceptive hostname contains `bajor.github.io` as a substring. It remains an external link. | Focused URL-classification unit test. |
| Fidelity | The linked cards remain raster and the badge is absent at oracle scales. | Real-consumer `make evaluate` at 18 and 72 DPI. |
| Accessibility | A keyboard user reaches the game anchor and receives a purpose-specific label. | Normal-mode Chromium DOM inspection. |
| Compatibility | YouTube and ordinary HTTP or HTTPS annotations retain their current target types. | Unit tests and real-consumer scene inspection. |

## Acceptance

The feature is accepted when focused tests pass, the refreshed Algorithms consumer parses both links, its normal viewer contains the secure game anchor and badge, its 18 and 72 DPI report passes unchanged thresholds, and the consumer workflow deploys from factory `main`.

## Amendment 1: Traceability Precedes Fraction Classification

Accepted on 2026-08-24.

[PRD 0004](/prd/0004-low-alpha-soft-masks.md) requires nonzero masks with no sample at or above alpha `96` to remain raster. Requirements 30 through 32 continue to govern masks that contain at least one traceable sample.

# References

1. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
2. [Linked game card decision](/adr/0004-linked-game-cards.md)
3. [Interactive linked-card behavior](/bdr/0004-interactive-linked-card-output.md)
4. [Observed source profile](/pdf-investigation.md)
5. [Low-alpha soft-mask requirements](/prd/0004-low-alpha-soft-masks.md)
