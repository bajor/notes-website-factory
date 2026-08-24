---
type: Issue
title: Preserve low-alpha soft masks
description: Retain faint source content as raster and redeploy the motivating consumer.
status: In Progress
timestamp: 2026-08-24
---
# Preserve Low-Alpha Soft Masks

## Scope

Implement [ADR 0005](/adr/0005-preserve-low-alpha-soft-masks-as-raster.md) and the mask scenarios in [BDR 0005](/bdr/0005-fidelity-preserving-mixed-scene-output.md). Keep the existing raster writer, scene schema, browser runtime, workflow interface, and evaluation thresholds.

## Acceptance Criteria

- Nonzero masks below the tracing cutoff remain raster.
- Empty and all-zero masks still fail explicitly.
- Masks containing traceable samples retain the existing fraction boundaries.
- Focused tests, `make test`, and factory `make evaluate` pass.
- The motivating consumer emits the low-alpha resource as a PNG and passes 18 and 72 DPI evaluation.
- Factory CI passes and the consumer Pages workflow deploys from updated factory `main`.

## Plan

1. Record the ordered classification contract and regression cases.
2. Add the low-alpha raster branch in `Factory.Vectorize`.
3. Run factory and real-consumer visual gates without changing thresholds.
4. Merge the factory pull request and dispatch the consumer workflow.

## Completion Evidence

To be completed with the factory pull request and consumer workflow run.

# References

1. [Low-alpha requirements](/prd/0004-low-alpha-soft-masks.md)
2. [Low-alpha raster decision](/adr/0005-preserve-low-alpha-soft-masks-as-raster.md)
3. [Fidelity-preserving mixed-scene behavior](/bdr/0005-fidelity-preserving-mixed-scene-output.md)
