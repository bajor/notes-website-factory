---
type: ADR
title: Preserve near-opaque linked cards and type exact game routes
description: Use an evidence-backed mask interval and a structural Algo Arcade URL boundary with normal-mode badges.
status: Accepted
timestamp: 2026-08-23
---
# Preserve Near-Opaque Linked Cards and Type Exact Game Routes

## Context

The refreshed Algorithms PDF contains two rounded linked cards with non-opaque sample fractions near `0.0082`; the least-transparent artwork resource is above `0.0336`. The old `0.005` raster boundary rejects those cards before annotation extraction. One annotation targets a specific Algo Arcade game while the existing link domain distinguishes only YouTube videos and generic external URLs.

## Decision

Preserve masks at or below `0.01`, reject masks between `0.01` and `0.02`, and trace masks at or above `0.02`. The measured gap keeps linked screenshots raster while retaining an explicit ambiguity interval.

Add `Game GameUrl` to `LinkTarget`. `Factory.Pdf` constructs it only for HTTPS URIs with exact case-insensitive host `bajor.github.io`, no credentials or port, exact path `/algo-arcade/`, and a non-empty `#/games/` fragment route. `site/runtime.js` renders that target as a secure native new-tab anchor and adds an inline SVG gamepad badge outside evaluation mode.

## Rejected Alternatives

- Keep the old mask thresholds: rejects observed near-opaque cards and prevents the supported consumer from building.
- Classify every mask below the vector threshold as raster: removes the explicit ambiguity failure required by the rendering policy.
- Match the host or `/games/` with string containment: lets deceptive hosts or unrelated pages receive a trusted game affordance.
- Embed games in an iframe: adds remote framing and permission behavior, obscures the instruction to continue on the game website, and complicates deterministic evaluation.
- Put the badge into evaluation screenshots: measures factory-synthesized interaction pixels against a PDF that cannot contain them.

## Consequences

The refreshed source produces 34 vector artworks and 7 raster assets, including both linked cards. Game links become explicit in scene JSON and accessible in the browser without changing the workflow interface. Provider and route matching are factory behavior, but no complete consumer URL or game slug is hard-coded. Normal and evaluation modes intentionally differ only by factory-owned interaction chrome.

# References

1. [Interactive game-link requirements](/prd/0003-interactive-game-links.md)
2. [Vector-first mixed rendering](/adr/0001-vector-first-mixed-rendering.md)
3. [Interactive linked-card behavior](/bdr/0004-interactive-linked-card-output.md)
4. [Observed source profile](/pdf-investigation.md)
