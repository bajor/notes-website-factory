---
type: PRD
title: OCR topic navigation
description: Requirements for indexing highlighter-framed headings and navigating smoothly to their board positions.
status: Accepted
timestamp: 2026-08-29
---
# OCR Topic Navigation

## Problem

A large Freeform board initially fits into one viewport, making its handwritten topic headings too small to scan. The existing zoom, fullscreen, and fit buttons do not expose the board's structure or move a reader directly to a selected subject. The observed source marks its topic headings with thick colored highlighter frames, but both the frames and handwriting are image pixels rather than PDF text.

## Goals

- Expose highlighter-framed headings as a compact topic index.
- Retain each heading's board position and navigate smoothly to local context around it.
- Keep the original board rendering unchanged and independent of OCR quality.
- Preserve mouse, touch, wheel, and keyboard pan and zoom behavior.

## Non-Goals

- Recovering all handwriting or general page text.
- Replacing source pixels with editable or selectable DOM text.
- Supporting arbitrary document layouts, printed-text regions, or unframed headings.
- Adding cloud OCR, caller-supplied OCR credentials, a backend, or browser-time recognition.
- Guaranteeing exact transcription of handwriting.

## Requirements

1. The factory must identify closed, thick, chromatic highlighter frames from decoded source pixels without depending on a fixed hue, resource name, board dimension, or expected count.
2. Thin outlines, open connectors, filled regions, and achromatic artwork must not become topics.
3. The factory must crop only each detected frame's interior, recognize one English text line with local Tesseract, and retain the frame's board-space bounds.
4. A successful empty OCR result must receive the deterministic label `Topic N`; a missing or failed OCR process must fail the build explicitly.
5. Topics must be ordered by top coordinate and then left coordinate, independent of OCR text.
6. Normal mode must expose only `Topics` and `Fit` in the bottom-left controls. Existing direct pan and zoom gestures and keys must remain available.
7. Selecting a topic must smoothly fit its surrounding context, support reduced-motion users, remain open on desktop, and close on mobile.
8. Evaluation mode must hide topic controls and continue comparing only PDF-derived pixels.

## Quality Attributes

| Attribute | Scenario | Instrument |
| --- | --- | --- |
| Fidelity | Topic recognition runs for a supported source. The generated board pixels and fixed 18/72 DPI metrics remain unchanged. | `make evaluate`, report inspection, and real-consumer comparison. |
| Reusability | A supported consumer uses another highlighter hue or board size. Relative geometry and chroma rules detect frames without caller configuration. | Synthetic image unit tests in multiple hues plus real-consumer validation. |
| Accessibility | A keyboard or reduced-motion user selects a topic. The control has an accessible name and navigation completes without forced animation. | Normal-mode Chromium interaction tests. |
| Build safety | Poppler or Tesseract cannot execute. The workflow emits a typed failure and no Pages artifact. | Process-boundary integration tests and reusable-workflow failure behavior. |

## Success Metrics

- The motivating consumer exposes all 12 visually observed highlighter-framed headings as navigation targets.
- Every emitted topic has non-empty text and valid in-board bounds; empty OCR output uses the documented fallback.
- The normal viewer contains no zoom-in, zoom-out, or fullscreen button.
- Factory and real-consumer 18/72 DPI evaluation pass without threshold changes.

## Acceptance

The capability is accepted when focused detector and ordering tests pass, local Tesseract produces or falls back to labels for the real consumer's 12 frames, desktop and mobile Chromium tests prove the control and navigation behavior, and factory plus consumer visual evaluation pass unchanged.

## Decision Log

- [ADR 0006](/adr/0006-build-time-topic-ocr.md) selects source-pixel frame detection and local Tesseract.
- [BDR 0006](/bdr/0006-topic-index-navigation.md) specifies observable build and browser behavior.
- [Issue 0005](/issues/0005-add-ocr-topic-navigation.md) tracks implementation and evidence.

# References

1. [Constitution Amendment 2](/constitution.md)
2. [Observed source profile](/pdf-investigation.md)
3. [Reusable factory requirements](/prd/0002-reusable-freeform-site-factory.md)
