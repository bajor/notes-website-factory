---
type: Issue
title: Add OCR topic navigation
description: Detect highlighter-framed headings, label them with local OCR, and navigate to their board positions.
status: In Progress
timestamp: 2026-08-29
---
# Add OCR Topic Navigation

## Scope

Implement [ADR 0006](/adr/0006-build-time-topic-ocr.md) and every scenario in [BDR 0006](/bdr/0006-topic-index-navigation.md). Preserve PDF-derived board rendering, direct pan and zoom interaction, workflow permissions, artifact names, and visual thresholds.

## Acceptance Criteria

- Source-independent relative geometry detects highlighter frames and rejects unrelated artwork.
- Local English Tesseract emits a label or deterministic fallback for each topic.
- The scene stores validated labels and board-space bounds separately from source nodes.
- Normal controls expose responsive `Topics` and `Fit` actions with accessible smooth navigation.
- Focused tests, `make test`, `make evaluate`, and test audit pass.
- Consumer revision `1bdf230` exposes all 12 observed frames and passes visual evaluation.
- Factory CI and the real consumer workflow pass without new workflow inputs or permissions.

## Plan

1. Record the constitutional exception, requirements, decision, behavior, architecture, and vocabulary.
2. Add pure frame detection and typed topic metadata.
3. Add bounded Poppler crops, Tesseract execution, cleanup, and workflow tooling.
4. Replace viewer buttons with the responsive topic index and animated target navigation.
5. Verify the synthetic fixture, normal/evaluation browser modes, visual fidelity, and real consumer.

## Completion Evidence

To be completed with the factory pull request and consumer workflow run before this issue is marked `Done`.

# References

1. [OCR topic navigation requirements](/prd/0005-ocr-topic-navigation.md)
2. [Build-time topic OCR decision](/adr/0006-build-time-topic-ocr.md)
3. [Topic index behavior](/bdr/0006-topic-index-navigation.md)
