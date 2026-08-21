---
type: Issue
title: Implement vector-first rendering
description: Deliver the approved mixed SVG/raster pipeline and its verification gates.
status: Done
timestamp: 2026-08-20
---
# Implement Vector-First Rendering

## Scope

Implement [ADR 0001](/adr/0001-vector-first-mixed-rendering.md) and prove [BDR 0001](/bdr/0001-mixed-scene-output.md) without adding a production dependency.

## Acceptance Criteria

- Pure classification and contour tracing have focused unit tests, including ambiguity and enclosed holes.
- The interpreter preserves mixed source order.
- Only referenced raster resources are materialized.
- The browser renders vector artwork as inline SVG and contains no Canvas fallback.
- `make validate-dist` enforces 35 vector nodes, 9 raster nodes, and 9 assets.
- 18 and 72 DPI evaluation passes without weaker thresholds.
- Desktop and mobile interactions are verified.
- Architecture, source-profile documentation, and the PR review SVG match the implementation.
