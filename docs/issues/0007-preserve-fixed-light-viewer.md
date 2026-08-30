---
type: Issue
title: Preserve fixed light viewer
description: Prevent browser theme adaptation from changing generated board and scene colors.
status: In Progress
timestamp: 2026-08-30
---
# Preserve Fixed Light Viewer

## Scope

Implement [BDR 0008](/bdr/0008-fixed-light-viewer.md) in the factory-owned viewer without changing PDF parsing, generated scene data, evaluation thresholds, or the reusable-workflow interface.

## Acceptance Criteria

- Generated HTML declares that only light presentation is supported before loading CSS.
- Root CSS forbids browser color-scheme overrides while retaining existing explicit colors.
- Normal and Chromium Auto Dark runtime captures are byte-identical.
- `make test` and `make evaluate` pass.
- The `notes-gcp` consumer rebuilds successfully and its deployed site retains the light presentation under Chromium Auto Dark Theme.

## Plan

1. Add the document-level and root-element fixed-light declarations.
2. Add a focused browser runtime regression check.
3. Verify the factory fixture and the motivating consumer.

# References

1. [Fixed light behavior](/bdr/0008-fixed-light-viewer.md)
2. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
