---
type: Issue
title: Preserve fixed light viewer
description: Prevent browser theme adaptation from changing generated board and scene colors.
status: Done
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

## Completion

Factory pull request [#20](https://github.com/bajor/notes-website-factory-workflow/pull/20) delivered the fixed-light declarations and browser regression check in merge commit `aea231e58466f44c060de0d3c207babdff13a9f4`. Factory `make test`, `make evaluate`, and reusable-workflow CI passed.

Consumer run [33305774440](https://github.com/bajor/notes-gcp/actions/runs/33305774440) checked out that exact factory merge commit, parsed the complete `notes-gcp` source, passed both visual scales, uploaded both artifacts, and deployed GitHub Pages. The accepted consumer metrics were:

| DPI | Mean error | Pixels within tolerance | Ink ratio |
| --- | ---: | ---: | ---: |
| 18 | 0.00223946896487991 | 0.9921176074011082 | 1.0157885788047185 |
| 72 | 0.0016175143925352563 | 0.9945225345873541 | 1.034645959740838 |

The deployed [GCP DE site](https://bajor.github.io/notes-gcp/) contains the document metadata and root CSS declarations. Normal and forced Chromium Auto Dark captures at `1600 x 900` pixels were byte-identical with SHA-256 `d30e94caa3a62a8d85a6e6f0761b74f6253a37906ff5f5a54279f81cfef370dd`.

# References

1. [Fixed light behavior](/bdr/0008-fixed-light-viewer.md)
2. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
