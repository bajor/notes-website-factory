---
type: PRD
title: Composited OCR topic navigation
description: Requirements for indexing rendered highlighter frames and navigating to their board positions.
status: Superseded
supersedes: "0006"
superseded_by: "0009"
timestamp: 2026-08-29
---
# Composited OCR Topic Navigation

## Problem

A visible Freeform frame can be assembled from overlapping image XObjects, so per-resource inspection can miss the frame or select unrelated colored artwork. Readers still need a compact index for the large board.

## Requirements

1. The build must detect closed, thick, chromatic frames from a temporary composited page render without depending on hue, filename, dimensions, resource names, or expected count.
2. Detection must not OCR the full page. Tesseract must receive only each accepted frame interior at OCR resolution.
3. Topics must be grouped into overlapping visual rows, ordered top-to-bottom by row and left-to-right within each row, then serialized with valid board-space bounds.
4. Empty OCR output must become `Topic N`; Poppler or Tesseract failure must abort the build.
5. Normal controls must contain only `Topics` and `Fit`; scenes without topics must show only `Fit`.
6. Selection must frame local context in about 450 milliseconds, allow direct interaction to cancel motion, honor reduced motion, avoid the open desktop panel, and close the mobile panel at `720px` or below.
7. Evaluation mode must hide all controls. Temporary renders and crops must remain outside the site artifact.

## Quality Attributes

| Attribute | Scenario | Instrument |
| --- | --- | --- |
| Reusability | Frame hue and board size differ. | Synthetic detector tests and real-consumer inspection. |
| Accessibility | Keyboard or reduced-motion readers use navigation. | Chromium runtime tests and manual inspection. |
| Fidelity | Topic metadata is enabled. | Fixed `make evaluate` thresholds and report inspection. |

## Acceptance

The motivating consumer exposes all 12 visually observed frames, factory and consumer gates pass, and no PDF, detection raster, crop, or OCR executable enters the Pages artifact.

# References

1. [Superseded requirements](/prd/0006-ocr-topic-navigation.md)
2. [Composited detection decision](/adr/0008-composited-topic-detection.md)
3. [Current topic behavior](/bdr/0010-composited-topic-index-navigation.md)
4. [Implementation issue](/issues/0008-add-ocr-topic-navigation.md)
